#ifndef __CACHE_H
#define __CACHE_H

#include "Config.h"
#include "Request.h"
#include "Statistics.h"
#include "SpatialPredictor.h"
#include "StridePrefetcher.h"
#include "CacheSet.h"

#include <algorithm>
#include <cstdio>
#include <cassert>
#include <functional>
#include <list>
#include <map>
#include <memory>
#include <queue>
#include <list>

namespace ramulator
{
class CacheSystem;

class Cache {
protected:
  ScalarStat cache_read_miss;
  ScalarStat cache_write_miss;
  ScalarStat cache_prefetch_miss;
  ScalarStat cache_prefetch_hit;
  ScalarStat cache_total_miss;
  ScalarStat cache_eviction;
  ScalarStat cache_read_access;
  ScalarStat cache_write_access;
  ScalarStat cache_prefetch_access;
  ScalarStat cache_total_access;
  ScalarStat cache_mshr_hit;
  ScalarStat cache_mshr_sector_hit;
  ScalarStat cache_mshr_unavailable;
  ScalarStat cache_set_unavailable;
  ScalarStat cache_set_cannot_evict;
  ScalarStat cache_sector_miss;
  ScalarStat cache_sector_hit;
  ScalarStat cache_fetched_unused;
  ScalarStat cache_fetched_used;
  ScalarStat cache_notfetched_unused;

                  

public:
  enum class Level {
    L1,
    L2,
    L3,
    MAX
  } level;
  std::string level_string;

  struct Line {
    long addr;
    long tag;
    bool lock; // When the lock is on, the value is not valid yet.
    bool dirty;
    long inst_addr; // The inst address of the load/store instruction that brought this cache block to this level 
    ulong sector_bits;
    ulong used_sectors;
    bool is_prefetch;
    // TODO: is this constructor used for read misses?
    Line(long addr, long tag):
        addr(addr), tag(tag), lock(true), dirty(false), sector_bits(0), used_sectors(0), inst_addr(0) {}
    Line(long addr, long tag, bool lock, bool dirty, ulong sector_bits, ulong used_sectors, long req_inst_addr):
        addr(addr), tag(tag), lock(lock), dirty(dirty), sector_bits(sector_bits), used_sectors(used_sectors), inst_addr(req_inst_addr), is_prefetch(false){}
    Line(long addr, long tag, bool lock, bool dirty, ulong sector_bits, ulong used_sectors, long req_inst_addr, bool is_prefetch):
        addr(addr), tag(tag), lock(lock), dirty(dirty), sector_bits(sector_bits), used_sectors(used_sectors), inst_addr(req_inst_addr), is_prefetch(is_prefetch){}
  };

  Cache(int id, int size, int assoc, int block_size, int mshr_entry_num,
      Level level, std::shared_ptr<CacheSystem> cachesys, const Config &configs);

  void tick();
  void gatherFromHigherLevels();

  void turnSectoredDRAMOff();
  void turnSectoredDRAMOn();

  int coreid = 0;

  long sectors_requested = 0;
  long sectors_requested_from_lower = 0;

  // L1, L2, L3 accumulated latencies
  int latency[int(Level::MAX)] = {4, 4 + 12, 4 + 12 + 31};
  int latency_each[int(Level::MAX)] = {4, 12, 31};

  std::shared_ptr<CacheSystem> cachesys;
  // LLC has multiple higher caches
  std::vector<Cache*> higher_cache;
  Cache* lower_cache;
  SpatialPredictor sp;

  StridePrefetcher* prefetcher; // FIXME: Change the type to a base class for prefetchers
                                // after implementing multiple types of prefetchers


  bool send(Request req);

  void concatlower(Cache* lower);

  void callback(Request& req);

  ulong findActualAccess(const Request& req);
  ulong find_missing_sectors(std::list<Line>::iterator &line, ulong sector_bits);
  ulong find_missing_sectors(ulong previously_requested_sectors, ulong sector_bits);
  bool sectoredDRAM;
  bool partialActivationDRAM;
  bool DGMS;

  bool spatial_predictor;

  int sector_size;

protected:

  bool is_first_level;
  bool is_second_level;
  bool is_last_level;
  size_t size;
  unsigned int assoc;
  unsigned int block_num;
  unsigned int index_mask;
  unsigned int block_size;
  unsigned int index_offset;
  unsigned int tag_offset;
  unsigned int mshr_entry_num;

  typedef struct
  {
    long tag;
    ulong sector_bits;
    bool dirty;
    ulong will_be_used_sectors;
    ulong will_be_dirty_sectors;
  } mshr_entry_type;

  std::vector<mshr_entry_type> mshr_entries;
  std::list<Request> retry_list;

  std::vector<CacheSet> cache_sets;

  int calc_log2(int val) {
      int n = 0;
      while ((val >>= 1))
          n ++;
      return n;
  }

  int get_index(long addr) {
    return (addr >> index_offset) & index_mask;
  };

  long get_tag(long addr) {
    return (addr >> tag_offset);
  }

  // Align the address to cache line size
  long align(long addr) {
    return (addr & ~(block_size-1l));
  }

  // check if the cache line can be evicted
  // from this and higher cache levels
  // @param addr address causing eviction
  // @param tag tag of victim block
  bool evictable(const long victim_addr);

  // Invalidate all copies of victim in higher levels 
  // also in this level. Return if dirty (we must WRITE)
  // We also update the spatial predictor at the first level
  bool evictBlock(const long victim_addr);

  ulong getUsedSectors(const long victim_addr);
  ulong getDirtySectors(const long victim_addr);
  ulong getSectors(const long victim_addr);

  // Used during evictions in higher level caches that need to update this cache
  void update(const long addr, const bool dirty, const ulong sector_bits = 0, const ulong used_sectors = 0, const ulong dirty_sectors = 0);

  void evict(const long victim_addr);

  // Print out the state of a set in all cache blocks
  void dumpSet(const long addr);

};

class CacheSystem {
public:
  CacheSystem(const Config& configs, std::function<bool(Request)> send_memory):
    send_memory(send_memory) {
      if (configs.has_core_caches()) {
        first_level = Cache::Level::L1;
      } else if (configs.has_l3_cache()) {
        first_level = Cache::Level::L3;
      } else {
        last_level = Cache::Level::MAX; // no cache
      }

      if (configs.has_l3_cache()) {
        last_level = Cache::Level::L3;
      } else if (configs.has_core_caches()) {
        last_level = Cache::Level::L2;
      } else {
        last_level = Cache::Level::MAX; // no cache
      }
    }

  // wait_list contains miss requests with their latencies in
  // cache. When this latency is met, the send_memory function
  // will be called to send the request to the memory system.
  std::list<std::pair<long, Request> > wait_list;

  // hit_list contains hit requests with their latencies in cache.
  // callback function will be called when this latency is met and
  // set the instruction status to ready in processor's window.
  std::list<std::pair<long, Request> > hit_list;

  std::function<bool(Request)> send_memory;

  long clk = 0;
  void tick();

  Cache::Level first_level;
  Cache::Level last_level;
};

} // namespace ramulator

#endif /* __CACHE_H */
