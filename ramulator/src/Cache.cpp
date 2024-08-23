#include "Cache.h"

#ifndef DEBUG_CACHE
#define debug(...)
#else
#define debug(...) do { \
          printf("\033[36m[DEBUG] %s ", __FUNCTION__); \
          printf(__VA_ARGS__); \
          printf("\033[0m\n"); \
      } while (0)
#endif

namespace ramulator
{

Cache::Cache(int id, int size, int assoc, int block_size,
    int mshr_entry_num, Level level,
    std::shared_ptr<CacheSystem> cachesys, const Config &configs):
    level(level), cachesys(cachesys), higher_cache(0),
    lower_cache(nullptr), size(size), assoc(assoc),
    block_size(block_size), mshr_entry_num(mshr_entry_num), sp(configs, id)
{
  coreid = id;

  if (configs.is_slow_cache())
  {
    latency[0] = 5;
    latency[1] = 18;
    latency[2] = 50;

    latency_each[0] = 5;
    latency_each[1] = 13;
    latency_each[2] = 32;
  }

  sector_size = configs.get_sector_size();
  spatial_predictor = configs.is_spatial_predictor_enabled();

  debug("level %d size %d assoc %d block_size %d\n",
      int(level), size, assoc, block_size);

  if (level == Level::L1) {
    level_string = "L1";
  } else if (level == Level::L2) {
    level_string = "L2";
  } else if (level == Level::L3) {
    level_string = "L3";
  }

  is_first_level = (level == cachesys->first_level);
  is_second_level = (level == Level::L2);
  is_last_level = (level == cachesys->last_level);

  // Check size, block size and assoc are 2^N
  assert((size & (size - 1)) == 0);
  assert((block_size & (block_size - 1)) == 0);
  assert((assoc & (assoc - 1)) == 0);
  assert(size >= block_size);

  // Initialize cache configuration
  block_num = size / (block_size * assoc);
  index_mask = block_num - 1;
  index_offset = calc_log2(block_size);
  tag_offset = calc_log2(block_num) + index_offset;

  prefetcher = nullptr;

  debug("index_offset %d", index_offset);
  debug("index_mask 0x%x", index_mask);
  debug("tag_offset %d", tag_offset);

  // Initialize cache sets
  cache_sets = std::vector<CacheSet>();
  for (int i = 0 ; i < block_num ; i++)
    cache_sets.push_back(CacheSet(assoc, CacheSet::PolicyType::MRU));

  printf("coreid:%d\n",coreid);

  sectoredDRAM = configs.is_sectoredDRAM();
  DGMS = configs.is_DGMS();
  partialActivationDRAM = configs.is_partialActivationDRAM();

    // regStats
  cache_read_miss.name(level_string + string("_cache_read_miss"))
                 .desc("cache read miss count")
                         .coreid(std::to_string(coreid))
                 .precision(0)
                 ;

  cache_write_miss.name(level_string + string("_cache_write_miss"))
                  .desc("cache write miss count")
                         .coreid(std::to_string(coreid))
                  .precision(0)
                  ;

  cache_total_miss.name(level_string + string("_cache_total_miss"))
                  .desc("cache total miss count")
                         .coreid(std::to_string(coreid))
                  .precision(0)
                  ;

  cache_sector_miss.name(level_string + string("_cache_sector_miss"))
                  .desc("cache total sector miss count")
                         .coreid(std::to_string(coreid))
                  .precision(0)
                  ;

  cache_prefetch_miss.name(level_string + string("_cache_prefetch_miss"))
                  .desc("cache prefetch miss count")
                         .coreid(std::to_string(coreid))
                  .precision(0)
                  ;

  cache_prefetch_hit.name(level_string + string("_cache_prefetch_hit"))
                    .desc("prefetch requests that were already in the cache")
                         .coreid(std::to_string(coreid))
                    .precision(0)
                    ;

  cache_sector_hit.name(level_string + string("_cache_sector_hit"))
                  .desc("cache total sector hit count")
                         .coreid(std::to_string(coreid))
                  .precision(0)
                  ;

  cache_fetched_unused.name(level_string + string("_cache_fetched_unused_sectors"))
                  .desc("total number of sectors that were fetched but not used")
                         .coreid(std::to_string(coreid))
                  .precision(0)
                  ;

  cache_fetched_used.name(level_string + string("_cache_fetched_used_sectors"))
                  .desc("total number of sectors that were fetched and used")
                         .coreid(std::to_string(coreid))
                  .precision(0)
                  ;

  cache_notfetched_unused.name(level_string + string("_cache_notfetched_unused_sectors"))
                  .desc("total number of sectors that were not fetched nor used")
                         .coreid(std::to_string(coreid))
                  .precision(0)
                  ;                  

  cache_eviction.name(level_string + string("_cache_eviction"))
                .desc("number of evict from this level to lower level")
                         .coreid(std::to_string(coreid))
                .precision(0)
                ;

  cache_read_access.name(level_string + string("_cache_read_access"))
                  .desc("cache read access count")
                         .coreid(std::to_string(coreid))
                  .precision(0)
                  ;

  cache_write_access.name(level_string + string("_cache_write_access"))
                    .desc("cache write access count")
                         .coreid(std::to_string(coreid))
                    .precision(0)
                    ;

  cache_prefetch_access.name(level_string + string("_cache_prefetch_access"))
                       .desc("cache prefetch access count")
                         .coreid(std::to_string(coreid))
                       .precision(0)
                       ;
                       
  cache_total_access.name(level_string + string("_cache_total_access"))
                    .desc("cache total access count")
                         .coreid(std::to_string(coreid))
                    .precision(0)
                    ;

  cache_mshr_hit.name(level_string + string("_cache_mshr_hit"))
                .desc("cache mshr hit count")
                         .coreid(std::to_string(coreid))
                .precision(0)
                ;

  cache_mshr_sector_hit.name(level_string + string("_cache_mshr_sector_hit"))
                .desc("cache mshr sector hit count")
                         .coreid(std::to_string(coreid))
                .precision(0)
                ;

  cache_mshr_unavailable.name(level_string + string("_cache_mshr_unavailable"))
                         .desc("cache mshr not available count")
                         .coreid(std::to_string(coreid))
                         .precision(0)
                         ;
  cache_set_unavailable.name(level_string + string("_cache_set_unavailable"))
                         .desc("cache set not available")
                         .coreid(std::to_string(coreid))
                         .precision(0)
                         ;

  cache_set_cannot_evict.name(level_string + string("_cache_set_cannot_evict"))
                         .desc("cache set eviction not possible")
                         .coreid(std::to_string(coreid))
                         .precision(0)
                         ;

};

void Cache::turnSectoredDRAMOn()
{
  for (auto hc: higher_cache)
    hc->turnSectoredDRAMOn();
  
  sectoredDRAM = true;
}

void Cache::turnSectoredDRAMOff()
{
  for (auto hc: higher_cache)
    hc->turnSectoredDRAMOff();
  
  sectoredDRAM = false;
}

ulong Cache::findActualAccess(const Request& req)
{
  return req.actual_access;
  /*
    // One-hot encoding the number of bits that should be set
    // e.g., if req_size is 8 bytes, and each sector is 8 bytes should be 0x000...001
    ulong n_sector_bits = (1 << (req.size/sector_size == 0 ? 1 : req.size/sector_size)) - 1;
    // Which sectors in the cache block are we going to access, shift sector bits accordingly
    ulong sector_bits_offset = ((req.addr & 0x3f)/sector_size);
    return n_sector_bits << sector_bits_offset;
  */
}

bool Cache::send(Request req) {
  debug("level %d req.addr %lx req.type %d, index %d, tag %ld, sectors %ld, type %d",
      int(level), req.addr, int(req.type), get_index(req.addr),
      get_tag(req.addr), req.sector_bits[int(level)], req.type);

  debug("sector bits: 0x%lx actual access: 0x%lx\n", req.sector_bits[int(level)], findActualAccess(req));
  //printf("sector bits: 0x%lx actual access: 0x%lx\n", req.sector_bits[int(level)], findActualAccess(req));

  sectors_requested += __builtin_popcountll(req.sector_bits[int(level)]);

  if (int(level) == 1)
  {
    //if (sectors_requested % 1024 < 8)
    //  printf("sectors requested so far: %ld\n", sectors_requested);
    //printf("addr: 0x%lx index: %d, tag: 0x%lx sector bits: 0x%lx actual access: 0x%lx\n", req.addr, get_index(req.addr), get_tag(req.addr), req.sector_bits[int(level)], findActualAccess(req));
  }

  if (sectoredDRAM && sector_size == 8)
  {
    ulong level_sector_bits = is_first_level ? req.sector_bits[0] : is_second_level ? req.sector_bits[1] : req.sector_bits[2];
    assert(level_sector_bits < 256 && "sector bits are too large");
  }

  cache_total_access++;
  if (req.type == Request::Type::WRITE) {
    cache_write_access++;
  } else if (req.type == Request::Type::READ) {
    cache_read_access++;
  } else {
    assert(req.type == Request::Type::PREFETCH);
    cache_prefetch_access++;
  }


  // Atb: find the cache set to access
  int set_idx = (req.addr >> index_offset) & index_mask;
  CacheSet& set = cache_sets[set_idx];

  /*
  if (is_first_level && spatial_predictor)
  {
    ulong sp_sector_bits = sp.predict(req.inst_addr, req.addr);
    //if (sp_sector_bits)
      //printf("SP PREDICTION: 0x%lx\n", sp_sector_bits);
    // Augment sector bits required by the processor with the spatial prediction
    req.sector_bits[0] |= sp_sector_bits;
  }
  */

  if (sectoredDRAM && sector_size == 8)
  {
    ulong level_sector_bits = is_first_level ? req.sector_bits[0] : is_second_level ? req.sector_bits[1] : req.sector_bits[2];
    assert(level_sector_bits < 256 && "Spatial predictor messed up sector bits");
  }

  // Extract stuff from request
  ulong level_sector_bits = 0UL;

  if(sectoredDRAM || DGMS)
    level_sector_bits = is_first_level ? req.sector_bits[0] : is_second_level ? req.sector_bits[1] : req.sector_bits[2];

  if(partialActivationDRAM)
    level_sector_bits = (1 << (64/sector_size)) - 1;

  //assert(!((~level_sector_bits) & findActualAccess(req)) && "Request accesses sectors it does not bring...");

  long tag = req.addr >> tag_offset;
  long block_num = req.addr >> index_offset;

  bool is_valid = set.isValid(tag);
    
  // block missed in cache
  // this does not cover sector misses
  if (!is_valid)
  {
    // Find if requested sectors are partially covered by MSHRs
    ulong remaining_sector_bits = level_sector_bits;
    // Check if any MSHR is trying to bring this block in
    bool any_mshr_match = false;
    for (int i = 0 ; i < mshr_entries.size() ; i++)
    {
      // Found matching MSHR
      if (mshr_entries[i].tag == block_num)
      {
        any_mshr_match = true;
        mshr_entries[i].dirty |= req.type == Request::Type::WRITE;
        if (req.type == Request::Type::WRITE)
        {
          assert(!(partialActivationDRAM || sectoredDRAM || DGMS) || findActualAccess(req));
          mshr_entries[i].will_be_dirty_sectors |= findActualAccess(req);
        }
        mshr_entries[i].will_be_used_sectors |= findActualAccess(req);
        // MSHR fully covers our sector bits, in this case we are fine
        if (!((~mshr_entries[i].sector_bits) & level_sector_bits))
        {
          cache_mshr_sector_hit++;
          debug("cache sector hit mshr");
          //req.cache_hit = true;
          //req.hit_level = int(level);
          //cachesys->hit_list.push_back(
            //make_pair(cachesys->clk + latency[int(level)], req));
          return true;
        }
        else
          remaining_sector_bits &= ~(mshr_entries[i].sector_bits);
      }
    }

    // No MSHR fully covers our block, but collectively some of them do
    if (remaining_sector_bits == 0 && level_sector_bits != 0)
    {
      cache_mshr_sector_hit++;
      debug("cache sector hit mshr (collective)");
      //req.cache_hit = true;
      //req.hit_level = int(level);
      //cachesys->hit_list.push_back(
        //make_pair(cachesys->clk + latency[int(level)], req));
      return true;
    }

    // We need to allocate a new MSHR for missing sectors
    if (any_mshr_match && req.type == Request::Type::READ)
    {

      ulong filtered_sector_bits = set.findMissingSectors(tag, remaining_sector_bits);
      
      // Some MSHRs will bring the sectors that are missing in the set eventually
      // so we can ignore this request
      if (filtered_sector_bits == 0UL)
      {
        debug("The request will hit in sector after MSHRs bring data");
        cache_mshr_sector_hit++;
        req.hit_level = int(level);
        req.cache_hit = true;
        // When WRITEs set the sector bits required by this request,
        // the MSHRs won't actually "trigger" matches in the wait list
        // so we need to count these as hits       
        cachesys->hit_list.push_back(
          make_pair(cachesys->clk + latency[int(level)], req));
        return true;
      }


      if (mshr_entries.size() == mshr_entry_num) 
      {
        cache_mshr_unavailable++;
        debug("There is an MSHR to same tag, but no mshr entries available for us to bring additional sectors");
        return false;
      }


      req.sector_bits[int(level) + 1] = filtered_sector_bits;

      // This is a miss, so we augment the sector bits
      if (is_first_level && spatial_predictor)
      {
        ulong sp_sector_bits = sp.predict(req.inst_addr, req.addr);
        //if (sp_sector_bits)
          //printf("SP PREDICTION: 0x%lx\n", sp_sector_bits);
        // Augment sector bits required by the processor with the spatial prediction
        req.sector_bits[int(level) + 1] |= sp_sector_bits;
        req.sector_bits[0] |= sp_sector_bits; // These will be available to the processor after they are brought
      }

      mshr_entry_type metr = {block_num, req.sector_bits[int(level) + 1], false, 0UL, 0UL};

      assert(!(sectoredDRAM || DGMS) || req.sector_bits[int(level) + 1] != 0 && "Cannot demand zero sectors from the lower level cache"); 

      mshr_entries.push_back(metr);

      debug("cache sector mshr miss");

      cache_sector_miss++;

      // Send the request to next level;
      if (!is_last_level) {
        if(!lower_cache->send(req)) {
          retry_list.push_back(req);
        }
        else
        {
          if (int(level) == 1)
          {
          //if (sectors_requested % 1024 < 8)
              //sectors_requested_from_lower += __builtin_popcount(req.sector_bits[int(level)+1]);
              //printf("sectors requested from lower level so far: %ld\n", sectors_requested_from_lower);
          }
        }        
      } else {
        cachesys->wait_list.push_back(
            make_pair(cachesys->clk + latency[int(level)], req));
      } 

      if(prefetcher && req.type != Request::Type::PREFETCH)
        prefetcher->miss(req.addr, cachesys->clk, req.sector_bits[int(level) + 1]); // try to retrieve the predicted sectors for the prefetched block

      return true;
    }
    // No need to allocate a new MSHR, we modify the MSHRs sector bits instead
    else if (any_mshr_match && req.type == Request::Type::WRITE)
    {
      for (int i = 0 ; i < mshr_entries.size() ; i++)
      {
        if (mshr_entries[i].tag == block_num)
        {
          set.insertSectors(tag, findActualAccess(req));
          set.access(tag, findActualAccess(req), true);
          //mshr_entries[i].sector_bits |= remaining_sector_bits;
          mshr_entries[i].dirty = true;
          //assert(findActualAccess(req));
          //mshr_entries[i].will_be_dirty_sectors = findActualAccess(req); // needed?
          cache_mshr_sector_hit++;
          debug("cache sector mshr hit (for writes that missed in mshrs)");
          return true;
        }
      }
      assert(false);
      return false;
    }
    // We need to allocate a new MSHR, and potentially a new cache block
    else
    {
      // Tag is both not valid nor busy, we need to allocate a new block
      if (!set.isBusy(tag))
      {
        long victim_tag = set.findVictim();
        // The victim is invalid already, just insert the new block
        // also make it busy s.t. it won't get evicted
        if (!set.isValid(victim_tag) && !set.isBusy(victim_tag))
        {
          if (mshr_entries.size() == mshr_entry_num) 
          {
            cache_mshr_unavailable++;
            debug("no mshr entry available");
            return false;
          }
          set.insert(victim_tag, tag, req.inst_addr, 0UL);
          // dumpSet(req.addr);
          set.makeBusy(tag);
        }
        else
        {
          long victim_addr = (victim_tag << tag_offset) | (set_idx << index_offset);
        
          // Check if the cache block can be evicted from this and higher levels
          if (this->evictable(victim_addr) && !set.isBusy(victim_tag))
          {
            assert(set.isValid(victim_tag) && "an invalid block turned out to be evictable");

            if (mshr_entries.size() == mshr_entry_num) 
            {
              cache_mshr_unavailable++;
              debug("no mshr entry available");
              return false;
            }
            debug("cache evict a block to allocate new block");
            this->evict(victim_addr);
            set.insert(victim_tag, tag, req.inst_addr, 0UL);
            // dumpSet(req.addr);
            set.makeBusy(tag);
          }
          else
          {
            cache_set_cannot_evict++;
            debug("Cannot evict from set because victim block is busy");
            return false;
          }
        }
      }
      else
      {
        if (req.type == Request::Type::PREFETCH)
        {
          printf("Some MSHR is trying to bring this prefetch request's block\n");
          return false;
        }
        dumpSet(req.addr);
        debug("This request's MSHR tag: 0x%lx", req.addr>>index_offset);
        for (int i = 0 ; i < mshr_entries.size() ; i++)
        {
          debug("MSHR%d waiting on address 0x%lx to bring sector bits %ld", i, mshr_entries[i].tag, mshr_entries[i].sector_bits);
        }
        assert(false && "No MSHRs match the block, but the block is busy");
      }
      // We need to allocate a new MSHR
      if (mshr_entries.size() == mshr_entry_num) 
      {
        cache_mshr_unavailable++;
        debug("no mshr entry available");
        return false;
      }
      else
      {
        // Create a new MSHR entry 
        bool dirty = req.type == Request::Type::WRITE;

        // This is a miss, so we augment the sector bits
        if (is_first_level && spatial_predictor)
        {
          ulong sp_sector_bits = sp.predict(req.inst_addr, req.addr);
          //if (sp_sector_bits)
            //printf("SP PREDICTION: 0x%lx\n", sp_sector_bits);
          // Augment sector bits required by the processor with the spatial prediction
          remaining_sector_bits |= sp_sector_bits;
          req.sector_bits[0] |= sp_sector_bits; // These will be available to the processor after they are brought

          //req.sector_bits[int(level) + 1] |= sp_sector_bits;
        }

        mshr_entry_type metr = {block_num, remaining_sector_bits, dirty, 0UL, remaining_sector_bits & findActualAccess(req)};
        mshr_entries.push_back(metr);
        assert(!set.isValid(tag) && set.isBusy(tag) && "Expected block to be not valid and busy");

        // The block is not filled in, that's why we're here
        req.sector_bits[int(level) + 1] = find_missing_sectors(0UL, remaining_sector_bits);
        assert(!(sectoredDRAM || DGMS) || req.sector_bits[int(level) + 1] != 0 && "Cannot demand zero sectors from the lower level cache"); 

        if (req.type == Request::Type::WRITE) {
          cache_write_miss++;
        } else if (req.type == Request::Type::READ) {
          cache_read_miss++;
        } else {
          assert(req.type == Request::Type::PREFETCH);
          cache_prefetch_miss++;
        }

        if (level == Cache::Level::L3 && (req.type == Request::Type::READ))
          printf("address %lx misses in L3\n", req.addr);

        // REQ has to be READ because otherwise we won't receive a callback
        // and technically, to claim ownership we need to read the block first
        if (req.type != Request::Type::PREFETCH)
          req.type = Request::Type::READ;

        debug("cache block missed, allocate MSHR to retrieve");

        // Send the request to next level;
        if (!is_last_level) {
          if(!lower_cache->send(req)) {
            retry_list.push_back(req);
          }
          else
          {
            if (int(level) == 1)
            {
            //if (sectors_requested % 1024 < 8)
                //sectors_requested_from_lower += __builtin_popcount(req.sector_bits[int(level)+1]);
                //printf("sectors requested from lower level so far: %ld\n", sectors_requested_from_lower);
            }
          }          
        } else {
          cachesys->wait_list.push_back(
              make_pair(cachesys->clk + latency[int(level)], req));
        }

        if(prefetcher && req.type != Request::Type::PREFETCH)
          prefetcher->miss(req.addr, cachesys->clk, req.sector_bits[int(level) + 1]); // try to retrieve the predicted sectors for the prefetched block

        return true;
      }
    }
  }
  else
  {
    // block is present in cache, either we hit or we sector missed
    //printf("ADDR: %lx\n", req.addr);
    // check if we hit

    // TODO: Big change: compare actual requested bits instead of sector bits
    // This way, we will try to bring in all sector bits only if the actual request misses
    // TODO: Big unchange: remove above change because bugs, could make sense to explore that implementation
    // Ideally, sector bits can be regarded as hints but that would require a more complex design?
    if(set.areSectorsValid(tag, level_sector_bits))
    {
      //assert(!((~level_sector_bits) & findActualAccess(req)) && "Request is accessing sectors that it does not bring");

      // A prefetch request hit, we do not need to worry
      if(req.type == Request::Type::PREFETCH) {
          cache_prefetch_hit++;
          return true;;
      }

      cache_sector_hit++;
      set.access(tag, findActualAccess(req) & level_sector_bits, req.type == Request::Type::WRITE);
      // TODO: revisit the two lines below, do we still need them?
      req.hit_level = int(level);
      req.cache_hit = true;

      // To let higher caches know we return to the request only partially
      //for (int st = int(level) ; st >= 0 ; st--)
        //req.sector_bits[st] = findActualAccess(req);

      cachesys->hit_list.push_back(
          make_pair(cachesys->clk + latency[int(level)], req));

      debug("hit, update timestamp %ld", cachesys->clk);
      debug("hit finish time %ld",
          cachesys->clk + latency[int(level)]);

      // Update prefetcher on cache hit
      if(prefetcher && req.type != Request::Type::PREFETCH)
        prefetcher->hit(req.addr, cachesys->clk, level_sector_bits); // try to retrieve the predicted sectors for the prefetched block

      return true;
    }
    // we sector missed
    else
    {
      if (req.type == Request::Type::WRITE)
      {

        set.insertSectors(tag, findActualAccess(req));
        set.access(tag, findActualAccess(req), true);
        cache_sector_hit++;
        // TODO: revisit the two lines below, do we still need them?
        req.hit_level = int(level);
        req.cache_hit = true;
        return true;      
      }
      // read request sector missed
      else
      {
        assert((sectoredDRAM || DGMS) && "Sector miss occured but sectoredDRAM is disabled");

        // 1) an MSHR completely brings sector bits, return true

        // Redundant code, but it is fine as long as it works
        // Find if requested sectors are partially covered by MSHRs
        ulong remaining_sector_bits = level_sector_bits;
        // Check if any MSHR is trying to bring this block in
        bool any_mshr_match = false;
        for (int i = 0 ; i < mshr_entries.size() ; i++)
        {
          // Found matching MSHR
          if (mshr_entries[i].tag == block_num)
          {
            any_mshr_match = true;

            // MSHR fully covers our sector bits, in this case we are fine
            if (!((~mshr_entries[i].sector_bits) & level_sector_bits))
            {
              set.insertSectors(tag, findActualAccess(req));
              set.access(tag, findActualAccess(req), false);
              cache_mshr_sector_hit++;
              //req.cache_hit = true;
              //req.hit_level = int(level);
              //cachesys->hit_list.push_back(
                //make_pair(cachesys->clk + latency[int(level)], req));
              return true;
            }
            else
              remaining_sector_bits &= ~(mshr_entries[i].sector_bits);
          }
        }        

        // 2) No MSHR fully covers our block, but collectively some of them do
        if (remaining_sector_bits == 0)
        {
          set.insertSectors(tag, findActualAccess(req));
          set.access(tag, findActualAccess(req), false);
          cache_mshr_sector_hit++;
          //req.cache_hit = true;
          //req.hit_level = int(level);
          //cachesys->hit_list.push_back(
            //make_pair(cachesys->clk + latency[int(level)], req));
          return true;
        }

        // 3) Allocate new MSHR
        if (mshr_entries.size() == mshr_entry_num) 
        {
          cache_mshr_unavailable++;
          debug("no mshr entry available");
          return false;
        }
        else
        {
          ulong filtered_sector_bits = set.findMissingSectors(tag, remaining_sector_bits);
          
          // Some MSHRs will bring the sectors that are missing in the set eventually
          // so we can ignore this request
          if (filtered_sector_bits == 0UL)
          {
            debug("The request will hit in sector after MSHRs bring data");
            cache_mshr_sector_hit++;
            req.hit_level = int(level);
            req.cache_hit = true;
            set.insertSectors(tag, findActualAccess(req));
            set.access(tag, findActualAccess(req), false);
            // When WRITEs set the sector bits required by this request,
            // the MSHRs won't actually "trigger" matches in the wait list
            // so we need to count these as hits
            cachesys->hit_list.push_back(
              make_pair(cachesys->clk + latency[int(level)], req));
            return true;
          }

          // This is a miss, so we augment the sector bits
          if (is_first_level && spatial_predictor)
          {
            ulong sp_sector_bits = sp.predict(req.inst_addr, req.addr);
            //if (sp_sector_bits)
              //printf("SP PREDICTION: 0x%lx\n", sp_sector_bits);
            // Augment sector bits required by the processor with the spatial prediction
            filtered_sector_bits |= sp_sector_bits;
            req.sector_bits[0] |= sp_sector_bits; // These will be available to the processor after they are brought
            //req.sector_bits[int(level) + 1] |= sp_sector_bits;
          }

          // The block is not filled in, that's why we're here
          req.sector_bits[int(level) + 1] = filtered_sector_bits;
          // Create a new MSHR entry 
          mshr_entry_type metr = {block_num, req.sector_bits[int(level) + 1], false, 0UL, 0UL};
          mshr_entries.push_back(metr);
          set.makeBusy(tag);
          assert(set.isValid(tag) && "Expected block to be valid");

          debug("Sector missed");
          cache_sector_miss++;


          // Send the request to next level;
          if (!is_last_level) {
            if(!lower_cache->send(req)) {
              retry_list.push_back(req);
            }
            else
            {
              if (int(level) == 1)
              {
              //if (sectors_requested % 1024 < 8)
                  //sectors_requested_from_lower += __builtin_popcount(req.sector_bits[int(level)+1]);
                  //printf("sectors requested from lower level so far: %ld\n", sectors_requested_from_lower);
              }
            }
          } else {
            cachesys->wait_list.push_back(
                make_pair(cachesys->clk + latency[int(level)], req));
          }
          return true;
        }
      }
    }
  }
}

bool Cache::evictable(const long victim_addr) 
{
  bool evictable_higher_cache = true;

  for (auto hc: higher_cache)
    evictable_higher_cache &= hc->evictable(victim_addr);

  int set_idx = (victim_addr >> index_offset) & index_mask;
  CacheSet& set = cache_sets[set_idx];

  long victim_tag = victim_addr >> tag_offset;
  return set.canEvict(victim_tag) & evictable_higher_cache;
}

ulong Cache::getUsedSectors(const long victim_addr)
{
  ulong used_sectors_hc = 0UL;

  for (auto hc: higher_cache)
    used_sectors_hc |= hc->getUsedSectors(victim_addr);

  int set_idx = (victim_addr >> index_offset) & index_mask;
  CacheSet& set = cache_sets[set_idx];

  long victim_tag = victim_addr >> tag_offset;
  return set.getUsedSectors(victim_tag) | used_sectors_hc;  
}

ulong Cache::getDirtySectors(const long victim_addr)
{
  ulong used_sectors_hc = 0UL;

  for (auto hc: higher_cache)
    used_sectors_hc |= hc->getDirtySectors(victim_addr);

  int set_idx = (victim_addr >> index_offset) & index_mask;
  CacheSet& set = cache_sets[set_idx];

  long victim_tag = victim_addr >> tag_offset;
  return set.getDirtySectors(victim_tag) | used_sectors_hc;  
}


ulong Cache::getSectors(const long victim_addr)
{
  ulong used_sectors_hc = 0UL;

  for (auto hc: higher_cache)
    used_sectors_hc |= hc->getSectors(victim_addr);

  int set_idx = (victim_addr >> index_offset) & index_mask;
  CacheSet& set = cache_sets[set_idx];

  long victim_tag = victim_addr >> tag_offset;
  return set.getSectorBits(victim_tag) | used_sectors_hc;  
}

bool Cache::evictBlock(const long victim_addr)
{
  ulong used_sectors_hc = 0UL;

  bool dirty = false;

  for (auto hc: higher_cache)
    dirty |= hc->evictBlock(victim_addr); 

  //if (dirty && level == Level::L3)
    //printf("%s dirty:%d\n",level_string.c_str(), dirty);

  int set_idx = (victim_addr >> index_offset) & index_mask;
  CacheSet& set = cache_sets[set_idx];

  // Update spatial predictor and log stats?
  long victim_tag = victim_addr >> tag_offset;

  /*
  if (!set.isValid(victim_tag))
  {
    fprintf(stderr, "My Level is %s, trying to evict addr:0x%lx tag:0x%lx\n", level_string.c_str(),
      victim_addr, victim_tag);

    for (auto& c : higher_cache)
    {
      for (auto& hc : c->higher_cache)
      {
        hc->dumpSet(victim_addr);
      }
      c->dumpSet(victim_addr);
    }

    dumpSet(victim_addr);

    if (int(level) <= 1)
    {
      lower_cache->dumpSet(victim_addr);
      if (int(level) < 1)
        lower_cache->lower_cache->dumpSet(victim_addr);
    }    
  }
  */

  // assert(set.isValid(victim_tag) && "Evicting an invalid cache block");

  // The tag does not have to be valid, imagine 
  // this is a higher level cache, the block
  // we are trying to evict is in another private cache
  // or the block has been evicted some time ago from
  // this cache and not accessed again
  if (set.isValid(victim_tag))
  {
    ulong used_sectors = getUsedSectors(victim_addr);

    if (is_first_level && spatial_predictor)
    {
      //printf("Update spatial predictor: iaddr:0x%lx daddr:0x%lx sectors:0x%lx\n",set.getInstAddr(victim_tag), victim_addr, used_sectors);
      sp.update(set.getInstAddr(victim_tag), victim_addr, used_sectors);
    }

    if (!set.canEvict(victim_tag))
    {
      std::cout << "You are trying to evict a non-evictable block" << std::endl;
      return dirty;
    }

    cache_fetched_used += __builtin_popcountll(used_sectors);
    //debug("Evicting 0x%lx with sector 0x%lx and used 0x%lx bits", victim_addr, set.getSectorBits(victim_tag), set.getUsedSectors(victim_tag));
    // assume sector bits will definitely have more or equal bits set than used_sectors does
    //assert(__builtin_popcountll(set.getSectorBits(victim_tag) & (~used_sectors)) == 0 && "We did not use some sectors that we brought");
    cache_fetched_unused += __builtin_popcountll(set.getSectorBits(victim_tag) & (~used_sectors));
    //if (__builtin_popcountll(set.getSectorBits(victim_tag) & (~used_sectors)) > 0)
      //printf("This might be working");

    cache_notfetched_unused += __builtin_popcountll((~set.getSectorBits(victim_tag)) & ((1 << sector_size) - 1));

    if (!is_last_level)
      lower_cache->update(victim_addr, set.isDirty(victim_tag) | dirty, set.getSectorBits(victim_tag), set.getUsedSectors(victim_tag), set.getDirtySectors(victim_tag));

    return dirty | set.evict(victim_tag);
  }
  // This block does not exist so it is not dirty
  return dirty;
}

void Cache::evict(const long victim_addr) {
  debug("level %d miss evict victim %lx", int(level), victim_addr);
  cache_eviction++;

  int set_idx = (victim_addr >> index_offset) & index_mask;
  CacheSet& set = cache_sets[set_idx];
  long tag = victim_addr >> tag_offset;

  ulong all_sectors = getSectors(victim_addr);

  // We will use this to update the copy at the upper level and calculate some stats
  ulong all_used_sectors = getUsedSectors(victim_addr);
  ulong dirty_sectors = getDirtySectors(victim_addr);
  //printf("0x%lx\n",all_used_sectors);
  //assert(!sectoredDRAM || all_used_sectors && "Evicting a line with no used sectors...");
  // assert(!(sectoredDRAM || DGMS) || all_used_sectors && "Evicting a line with no used sectors...");
  
  // "Evict" from higher levels;
  bool dirty = evictBlock(victim_addr);

  // If LLC, send write request to memory (when dirty)
  if (is_last_level && dirty)
  {
    //printf("%lx\n",dirty_sectors);

    assert(!(sectoredDRAM || partialActivationDRAM || DGMS) || dirty_sectors && "Writing back a dirty cache block with no dirty sectors");
    //assert(false && "Does this work?");
    Request write_req(victim_addr, Request::Type::WRITE);
    write_req.sector_bits[3] = dirty_sectors;
    cachesys->wait_list.push_back(make_pair(cachesys->clk + latency[int(level)], write_req));
  }
  // If not LLC, update the cache line in the lower level
  // Evictblock already updates the lower level cache
  // if (!is_last_level)
    // lower_cache->update(victim_addr, dirty, all_sectors, all_used_sectors);
}

void Cache::dumpSet(const long addr)
{
  fprintf(stderr,"%s Tag:0x%lx", level_string.c_str(), addr >> tag_offset);

  int set_idx = (addr >> index_offset) & index_mask;
  CacheSet &set = cache_sets[set_idx];

  ulong valids = set.getValidVec();
  ulong busys = set.getBusyVec();
  ulong dirtys = set.getDirtyVec();

  std::vector<ulong> tags = set.getTags();

  for (int i = 0 ; i < assoc - 1 ; i++)
  {
    fprintf(stderr,"Tag:0x%08lx V:%lu B:%lu\t", tags[i], valids & 1, busys & 1);
    valids >>= 1;
    busys >>= 1;
    dirtys >>= 1;
  }

  fprintf(stderr,"Tag:0x%08lx V:%lu B:%lu\n", tags[assoc-1], valids & 1, busys & 1);
}

void Cache::update(const long addr, const bool dirty, const ulong sector_bits, const ulong used_sectors, const ulong dirty_sectors)
{
  int set_idx = (addr >> index_offset) & index_mask;
  CacheSet& set = cache_sets[set_idx];

  long tag = addr >> tag_offset;

  // Update both used and available sectors from the higher-level cache
  
  if (!(set.isValid(tag) || set.isBusy(tag)))
  {

    printf("My Level is %s, trying to update addr:0x%lx tag:0x%lx\n", level_string.c_str(),
      addr, tag);

    for (auto& c : higher_cache)
    {
      for (auto& hc : c->higher_cache)
      {
        hc->dumpSet(addr);
      }
      c->dumpSet(addr);
    }

    dumpSet(addr);

    if (int(level) <= 1)
    {
      lower_cache->dumpSet(addr);
      if (int(level) < 1)
        lower_cache->lower_cache->dumpSet(addr);
    }
  }

  assert((set.isValid(tag) || set.isBusy(tag)) && "Updating a non-existent cache block"); 
  
  //printf("%lx %lx %lx\n", sector_bits, used_sectors, dirty_sectors);

  set.insertSectors(addr >> tag_offset, sector_bits);
  set.access(addr >> tag_offset, used_sectors, false);

  if (dirty)
  {
    set.makeDirty(tag); 
    set.access(addr >> tag_offset, dirty_sectors, true);
  }
}

ulong Cache::find_missing_sectors(std::list<Line>::iterator &line, ulong sector_bits)
{
  return (~(line->sector_bits)) & sector_bits;
}

ulong Cache::find_missing_sectors(ulong previously_requested_sectors, ulong sector_bits)
{
  return (~previously_requested_sectors) & sector_bits;
}

void Cache::concatlower(Cache* lower) {
  lower_cache = lower;
  assert(lower != nullptr);
  lower->higher_cache.push_back(this);
};

void Cache::callback(Request& req) {
  debug("Level%d, addr:%ld", int(level),req.addr);

  // Unnecessary callbacks mess with SectorDRAM

  // if (req.type != Request::Type::PREFETCH)
  // {
  if (req.type == Request::Type::PREFETCH)
  {
    if (int(level) > 0)
      req.sector_bits[int(level) - 1] = req.sector_bits[int(level)];
  }

    if (higher_cache.size()) {
      for (auto hc : higher_cache) {
        hc->callback(req);
      }
    }
  // }

  debug("Level%d",int(level));

  // This callback does not concern our level anyways
  // it was a hit at a higher cache
  if (req.cache_hit && req.hit_level <= int(level))
    return;

  long tag = req.addr >> tag_offset;
  long block_num = req.addr >> index_offset;
  long set_idx = (req.addr >> index_offset) & index_mask;
  CacheSet& set = cache_sets[set_idx];

  int mshrs_to_remove = 0;
  int remove_indices[mshr_entry_num];

  bool any_match = false;

  for (int i = 0 ; i < mshr_entries.size() ; i++)
  {
    debug("MSHR%d waiting on address 0x%lx to bring sector bits %ld", i, mshr_entries[i].tag, mshr_entries[i].sector_bits);
    // Found matching MSHR
    if (mshr_entries[i].tag == block_num)
    {
      debug("mshr_entries[%d].sector_bits:%ld req.sector_bits:%ld", i, mshr_entries[i].sector_bits, req.sector_bits[int(level) + 1]);
      mshr_entries[i].sector_bits &= ~req.sector_bits[int(level) + 1];
      /*
      // The request brought the sectors the MSHR asked for completely 
      if (mshr_entries[i].sector_bits == req.sector_bits[int(level) + 1])
      {

        // TODO: bug: WRITE misses update the cache block's state but forget about MSHRs

      }
      */

      if (mshr_entries[i].sector_bits == 0UL)
      {
        assert(set.isBusy(tag) && "MSHR brought data to an idle block, which should never happen");

        any_match = true;
        bool other_match = false;

        for (int j = 0 ; j < mshr_entries.size() ; j++)
        {
          if (j == i) continue;
          
          if (mshr_entries[j].tag == mshr_entries[i].tag)
          {
            other_match = true;
            break;
          }
        }

        // these should happen only when there are no other MSHRs bringing data to this block
        if (!other_match)
        {
          set.makeIdle(tag);
          set.validate(tag); 
        }

        if (mshr_entries[i].dirty)
        {
          //printf("MSHR making a set dirty\n");
          set.makeDirty(tag);
        }

        assert((set.isValid(tag) || set.isBusy(tag)) && "MSHRs accessing an invalid block"); 
        set.insertSectors(tag, req.sector_bits[int(level) + 1] | mshr_entries[i].will_be_used_sectors);
        set.access(tag, (findActualAccess(req) & req.sector_bits[int(level) + 1]) | mshr_entries[i].will_be_used_sectors, false);
        
        if (mshr_entries[i].dirty)
          set.access(tag, mshr_entries[i].will_be_dirty_sectors, true);

        remove_indices[mshrs_to_remove] = (i - mshrs_to_remove);
        mshrs_to_remove++;        
      }
    }
  }

  debug("# of MSHRs that will be removed %d", mshrs_to_remove);
  debug("ReqAddr:%ld ReqTag:%ld SectorBits:%ld", req.addr, tag, req.sector_bits[int(level) + 1]);

  // TODO: this assumption breaks down on multi-core runs
  // as other cores' requests trigger the callback on another private cache? 
  //assert (any_match && "A request brought in sectors requested by no MSHRs");

  // TODO: Remove MSHRs at indices
  for (int i = 0 ; i < mshrs_to_remove ; i++)
    mshr_entries.erase(mshr_entries.begin() + remove_indices[i]);

  bool no_more_match = true;

  if (any_match)
  {
    for (int i = 0 ; i < mshr_entries.size() ; i++)
    {
      if(mshr_entries[i].tag == block_num) // to recover from the side effect when two mshrs get cleared in one go
      {
        no_more_match = false;
      }
    } 
  }
  
  if (any_match && no_more_match)
  {
    set.makeIdle(tag);
    set.validate(tag);
  }
}

void Cache::tick() {

    if(!lower_cache->is_last_level)
        lower_cache->tick();

    for (auto it = retry_list.begin(); it != retry_list.end(); it++) {
        if(lower_cache->send(*it))
        {
          if (int(level) == 1)
          {
          //if (sectors_requested % 1024 < 8)
              //sectors_requested_from_lower += __builtin_popcount(it->sector_bits[int(level)+1]);
              //printf("sectors requested from lower level so far: %ld\n", sectors_requested_from_lower);
          }
          it = retry_list.erase(it);
        }
    }

}

void Cache::gatherFromHigherLevels()
{
  assert(int(level) == 2 && "gatherFromHigherLevels called on non-LLC cache");
  for (int i = 0 ; i < size/(assoc * block_size) ; i++)
  {
    CacheSet &set = cache_sets[i];
    for (auto &tag : set.getTags())
    {
      long victim_addr = (tag << tag_offset) + (i * block_size);
      evictBlock(victim_addr);
    }
  }
}

void CacheSystem::tick() {
  debug("clk %ld", clk);

  //if (clk > 42500)
    //exit(0);

  ++clk;

  // Sends ready waiting request to memory
  auto it = wait_list.begin();
  while (it != wait_list.end() && clk >= it->first) {
    if (!send_memory(it->second)) {
      ++it;
    } else {

      debug("complete req: addr %lx", (it->second).addr);

      it = wait_list.erase(it);
    }
  }

  // hit request callback
  it = hit_list.begin();
  while (it != hit_list.end()) {
    if (clk >= it->first) {
      it->second.callback(it->second);

      debug("finish hit: addr %lx", (it->second).addr);

      it = hit_list.erase(it);
    } else {
      ++it;
    }
  }
}

} // namespace ramulator
