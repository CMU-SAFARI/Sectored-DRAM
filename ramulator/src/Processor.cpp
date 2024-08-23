#include "Processor.h"
#include <cassert>

using namespace std;
using namespace ramulator;

Processor::Processor(const Config& configs,
    vector<const char*> trace_list,
    function<bool(Request)> send_memory,
    MemoryBase& memory)
    : ipcs(trace_list.size(), -1),
    early_exit(configs.is_early_exit()),
    no_core_caches(!configs.has_core_caches()),
    no_shared_cache(!configs.has_l3_cache()),
    cachesys(new CacheSystem(configs, send_memory)),
    llc(0, l3_size, l3_assoc, l3_blocksz,
         mshr_per_bank * trace_list.size(),
         Cache::Level::L3, cachesys, configs) {

  assert(cachesys != nullptr);
  int tracenum = trace_list.size();
  assert(tracenum > 0);
  printf("tracenum: %d\n", tracenum);
  for (int i = 0 ; i < tracenum ; ++i) {
    printf("trace_list[%d]: %s\n", i, trace_list[i]);
  }
  if (no_shared_cache) {
    for (int i = 0 ; i < tracenum ; ++i) {
      cores.emplace_back(new Core(
          configs, i, trace_list[i], send_memory, nullptr,
          cachesys, memory));
    }
  } else {
    for (int i = 0 ; i < tracenum ; ++i) {
      cores.emplace_back(new Core(configs, i, trace_list[i],
          std::bind(&Cache::send, &llc, std::placeholders::_1),
          &llc, cachesys, memory));
    }
  }
  for (int i = 0 ; i < tracenum ; ++i) {
    cores[i]->callback = std::bind(&Processor::receive, this,
        placeholders::_1);
  }

  // regStats
  cpu_cycles.name("cpu_cycles")
            .desc("cpu cycle number")
            .precision(0)
            ;
  
  processor_energy.name("processor_energy")
            .desc("processor energy in mJ")
            .precision(8)
            ;

  
  cpu_cycles = 0;

  sector_size = configs.get_sector_size();

  if (!configs.is_dynamic_policy())
  {
    turnSectorDRAMOn();
  }


  if (configs.is_prefetcher()) {
      assert(!no_shared_cache && "ERROR: Currently, a shared LLC is required for the stride prefetcher!");

      // Stride prefetcher configuration
      int num_entries = configs.get_stride_pref_entries();
      int mode = configs.get_stride_pref_mode();
      int ss_thresh = configs.get_stride_pref_single_stride_tresh();
      int ms_thresh = configs.get_stride_pref_multi_stride_tresh();
      int start_dist = configs.get_stride_pref_stride_start_dist();
      int stride_degree = configs.get_stride_pref_stride_degree();
      int stride_dist = configs.get_stride_pref_stride_dist();

      StridePrefetcher * pref = new StridePrefetcher(num_entries, 
                      (StridePrefetcher::StridePrefMode) mode,
                      ss_thresh, ms_thresh, start_dist, stride_degree, stride_dist,
                      std::bind(&Cache::send, &llc, placeholders::_1),
                      std::bind(&Cache::callback, &llc, placeholders::_1),
                      std::bind(&Processor::receive, this, placeholders::_1));

      llc.prefetcher = pref;
  } 

}

void Processor::tick() {
  cpu_cycles++;

  
  /*
  if ((int(cpu_cycles.value()) % 50000) == 0)
    for (unsigned int i = 0 ; i < cores.size() ; ++i)
      cores[i].get()->dump_window();
  */
  //printf("Window head address: %lx window size: %d\n", cores[0].get()->window.addr_list[cores[0].get()->window.tail], cores[0].get()->window.size());

  if((int(cpu_cycles.value()) % 50000000) == 0)
      printf("CPU heartbeat, cycles: %d \n", (int(cpu_cycles.value())));

  if (!(no_core_caches && no_shared_cache)) {
    cachesys->tick();
  }
  for (unsigned int i = 0 ; i < cores.size() ; ++i) {
    Core* core = cores[i].get();
    core->tick();
  }
}

void Processor::receive(Request& req) {
  //printf("[Processor] Actually received a read response: IA:0x%lx A:0x%lx SB:%lx\n", req.inst_addr, req.addr, req.sector_bits[0]);

  // if (req.type == Request::Type::PREFETCH)
    // printf("Prefetch request calling back\n");

  if (!no_shared_cache) {
    llc.callback(req);
  } else if (!cores[0]->no_core_caches) {
    // Assume all cores have caches or don't have caches
    // at the same time.
    for (unsigned int i = 0 ; i < cores.size() ; ++i) {
      Core* core = cores[i].get();
      core->caches[0]->callback(req);
    }
  }
  for (unsigned int i = 0 ; i < cores.size() ; ++i) {
    Core* core = cores[i].get();
    core->receive(req);
  }
}

void Processor::finish()
{
  evictLLC();
  // Calculate dynamic energy
  double processor_energy_calc = 0;
  for (auto &core : cores)
  {
    core->calc_dyn_energy();
    processor_energy_calc += core->dynamic_energy.value();
  }
  processor_energy = processor_energy_calc + static_power * cpu_cycles.value()/cores[0]->clk_per_sec * 1000;
}

void Processor::turnSectorDRAMOff()
{
  for (auto &core : cores)
  {
    //core->sectoredDRAM = false;
    core->dynamicOn = false;
    core->traceDynamicOff();
  }

  //llc.turnSectoredDRAMOff();
}

void Processor::turnSectorDRAMOn()
{
  for (auto &core : cores)
  {
    //core->sectoredDRAM = true;
    core->dynamicOn = true;
    core->traceDynamicOn();
  }

  //llc.turnSectoredDRAMOn();
}

void Core::calc_dyn_energy()
{
  if (sectoredDRAM || DGMS)
    dynamic_energy = calc_ipc()/4 * sectored_core_dynamic_power * record_cycs.value()/clk_per_sec * 1000;
  else
    dynamic_energy = calc_ipc()/4 * baseline_core_dynamic_power * record_cycs.value()/clk_per_sec * 1000;
}

void Processor::evictLLC()
{
  assert(!no_shared_cache && "Evicting LLC where there is no LLC");
  llc.gatherFromHigherLevels();
}

bool Processor::finished() {
  if (early_exit) {
    for (unsigned int i = 0 ; i < cores.size(); ++i) {
      if (cores[i]->finished()) {
        for (unsigned int j = 0 ; j < cores.size() ; ++j) {
          ipc += cores[j]->calc_ipc();
        }
        return true;
      }
    }
    return false;
  } else {
    for (unsigned int i = 0 ; i < cores.size(); ++i) {
      if (!cores[i]->finished()) {
        return false;
      }
      if (ipcs[i] < 0) {
        ipcs[i] = cores[i]->calc_ipc();
        ipc += ipcs[i];
      }
    }
    return true;
  }
}

bool Processor::has_reached_limit() {
  for (unsigned int i = 0 ; i < cores.size() ; ++i) {
    if (!cores[i]->has_reached_limit()) {
      return false;
    }
  }
  return true;
}

long Processor::get_insts() {
    long insts_total = 0;
    for (unsigned int i = 0 ; i < cores.size(); i++) {
        insts_total += cores[i]->get_insts();
    }

    return insts_total;
}

void Processor::reset_stats() {
    for (unsigned int i = 0 ; i < cores.size(); i++) {
        cores[i]->reset_stats();
    }

    ipc = 0;

    for (unsigned int i = 0; i < ipcs.size(); i++)
        ipcs[i] = -1;
}

Core::Core(const Config& configs, int coreid,
    const char* trace_fname, function<bool(Request)> send_next,
    Cache* llc, std::shared_ptr<CacheSystem> cachesys, MemoryBase& memory)
    : id(coreid), no_core_caches(!configs.has_core_caches()),
    no_shared_cache(!configs.has_l3_cache()),
    llc(llc), trace(trace_fname), memory(memory)
{

  cout << "[Core] Sector Size: " << sector_size << endl;

  int cpu_tick = configs.get_cpu_tick();
  int mem_tick = configs.get_mem_tick();
  clk_per_sec = atol(configs["speed"].substr((configs["speed"].find("_") + 1)).c_str()) * 1000 * 1000 / mem_tick * cpu_tick; //in MHz
  printf("cpu_tick:%d mem_tick:%d CPU_clk_per_sec:%lld\n", cpu_tick,mem_tick,clk_per_sec); 

  sector_size = configs.get_sector_size();
  sectoredDRAM = configs.is_sectoredDRAM();
  DGMS = configs.is_DGMS();
  partialActivationDRAM = configs.is_partialActivationDRAM();
  trace.sector_size = sector_size;
  trace.sectoredDRAM = sectoredDRAM;
  trace.DGMS = DGMS;
  trace.partialActivationDRAM = partialActivationDRAM;
  trace.pretrace_buffer_size = configs.get_lookahead_size();
  lookahead_predictor = configs.is_lookahead_predictor_enabled();
  trace.lookahead_predictor = lookahead_predictor;

  // set expected limit instruction for calculating weighted speedup
  expected_limit_insts = configs.get_expected_limit_insts();
  trace.expected_limit_insts = expected_limit_insts;

  // Build cache hierarchy
  if (no_core_caches) {
    send = send_next;
  } else {
    // L2 caches[0]
    caches.emplace_back(new Cache(
        coreid, l2_size, l2_assoc, l2_blocksz, l2_mshr_num,
        Cache::Level::L2, cachesys, configs));
    // L1 caches[1]
    caches.emplace_back(new Cache(
        coreid, l1_size, l1_assoc, l1_blocksz, l1_mshr_num,
        Cache::Level::L1, cachesys, configs));
    send = bind(&Cache::send, caches[1].get(), placeholders::_1);
    if (llc != nullptr) {
      caches[0]->concatlower(llc);
    }
    caches[1]->concatlower(caches[0].get());

    first_level_cache = caches[1].get();
  }
  /*
  if (no_core_caches) {
    more_reqs = trace.get_filtered_request(
        bubble_cnt, req_addr, req_type, partial_tag);
    req_addr = memory.page_allocator(req_addr, id);
  } else {
    */
    more_reqs = trace.get_unfiltered_request(
        bubble_cnt, req_addr, req_type, sector_bits, req_size, req_inst_addr, req_actual_access);
    req_addr = memory.page_allocator(req_addr, id);
  //}

  
  // regStats
  record_cycs.name("record_cycs")
             .desc("Record cycle number for calculating weighted speedup. (Only valid when expected limit instruction number is non zero in config file.)")
             .coreid(std::to_string(id))
             .precision(0)
             ;

  record_insts.name("record_insts_core")
              .desc("Retired instruction number when record cycle number. (Only valid when expected limit instruction number is non zero in config file.)")
             .coreid(std::to_string(id))
              .precision(0)
              ;

  dynamic_energy.name("dynamic_energy_core")
              .desc("How much energy this core spent in mJ")
             .coreid(std::to_string(id))
              .precision(8)
              ;

  memory_access_cycles.name("memory_access_cycles_core")
                      .desc("memory access cycles in memory time domain")
             .coreid(std::to_string(id))
                      .precision(0)
                      ;
  memory_access_cycles = 0;
  cpu_inst.name("cpu_instructions")
          .desc("cpu instruction number")
             .coreid(std::to_string(id))
          .precision(0)
          ;
  cpu_inst = 0;

}

void Core::traceDynamicOff()
{
  trace.dynamicOn = false;
}

void Core::traceDynamicOn()
{
  trace.dynamicOn = true;
}



double Core::calc_ipc()
{
    printf("[%d]retired: %ld, clk, %ld\n", id, retired, clk);
    return (double) retired / clk;
}

void Core::dump_window()
{
  window.dump();
}

void Core::tick()
{
    clk++;

    if(first_level_cache != nullptr)
        first_level_cache->tick();

    retired += window.retire();

    if (expected_limit_insts == 0 && !more_reqs) return;

    // TODO, stop cores that have already finished executing
    if (expected_limit_insts == long(cpu_inst.value()) && reached_limit) return;

    // bubbles (non-memory operations)
    int inserted = 0;
    while (bubble_cnt > 0) {
        if (inserted == window.ipc) return;
        if (window.is_full()) return;

        window.insert(true, -1, 0UL);
        inserted++;
        bubble_cnt--;
        cpu_inst++;
        if (long(cpu_inst.value()) == expected_limit_insts && !reached_limit) {
          record_cycs = clk;
          record_insts = long(cpu_inst.value());
          memory.record_core(id);
          reached_limit = true;
        }
    }

    // cout << window.size() << endl;

    if (req_type == Request::Type::READ) {
        // read request
        if (inserted == window.ipc) return;
        if (window.is_full()) return;

        Request req(req_addr, req_type, callback, id);
        req.sector_bits[0] = sector_bits;
        req.sector_bits[1] = sector_bits;
        req.sector_bits[2] = sector_bits;
        req.size = req_size;
        req.inst_addr = req_inst_addr;
        req.actual_access = req_actual_access;
        if (!send(req)) return;
        //printf("[Processor] Actually sent a read request: IA:0x%lx A:0x%lx SB:%lx\n", req.inst_addr, req.addr, req.sector_bits[0]);
        window.insert(false, req_addr, sector_bits);
        cpu_inst++;
    }
    else {
        // write request
        assert(req_type == Request::Type::WRITE);
        Request req(req_addr, req_type, callback, id);
        req.sector_bits[0] = sector_bits;
        req.sector_bits[1] = sector_bits;
        req.sector_bits[2] = sector_bits;
        req.size = req_size;
        req.inst_addr = req_inst_addr;
        req.actual_access = req_actual_access;
        if (!send(req)) return;
        cpu_inst++;
    }
    if (long(cpu_inst.value()) == expected_limit_insts && !reached_limit) {
      record_cycs = clk;
      record_insts = long(cpu_inst.value());
      memory.record_core(id);
      reached_limit = true;
    }

    /*
    if (no_core_caches) {
      more_reqs = trace.get_filtered_request(
          bubble_cnt, req_addr, req_type,partial_tag);
      if (req_addr != -1) {
        req_addr = memory.page_allocator(req_addr, id);
      }
    } else { */
      more_reqs = trace.get_unfiltered_request(
          bubble_cnt, req_addr, req_type, sector_bits, req_size, req_inst_addr, req_actual_access);
      if (req_addr != -1) {
        req_addr = memory.page_allocator(req_addr, id);
      }
    //}
    if (!more_reqs) {
      if (!reached_limit) { // if the length of this trace is shorter than expected length, then record it when the whole trace finishes, and set reached_limit to true.
        // Hasan: overriding this behavior. We start the trace from the
        // beginning until the requested amount of instructions are
        // simulated. This should never be reached now.
        assert((expected_limit_insts == 0) && "Shouldn't be reached when expected_limit_insts > 0 since we start over the trace");
        record_cycs = clk;
        record_insts = long(cpu_inst.value());
        memory.record_core(id);
        reached_limit = true;
      }
    }
}

bool Core::finished()
{
    return !more_reqs && window.is_empty();
}

bool Core::has_reached_limit() {
  return reached_limit;
}

long Core::get_insts() {
    return long(cpu_inst.value());
}

void Core::receive(Request& req)
{
    // sector bits 1 because those are what brought to L1
    window.set_ready(req.addr, ~(l1_blocksz - 1l), req.sector_bits[0]);
    if (req.arrive != -1 && req.depart > last) {
      memory_access_cycles += (req.depart - max(last, req.arrive));
      last = req.depart;
    }
}

void Core::reset_stats() {
    clk = 0;
    retired = 0;
    cpu_inst = 0;
}

bool Window::is_full()
{
    return load == depth;
}

bool Window::is_empty()
{
    return load == 0;
}

int Window::size()
{
    return load;
}

void Window::dump()
{
    printf("Dumping instruction window starting from tail\n");
    for (int i = 0 ; i < load; i++)
    {
        int index = (tail + i) % depth;
        printf("%03d: ADDR:0x%016lx READY:%s WAITING FOR SECTORS: 0x%lx\n", i, addr_list[index], ready_list[index] ? "yes" : "no", sector_list[index]);
    }
}

void Window::insert(bool ready, long addr, ulong sectors = 0UL)
{
    assert(load <= depth);

    ready_list.at(head) = ready;
    addr_list.at(head) = addr;
    sector_list.at(head) = sectors;

    head = (head + 1) % depth;
    load++;
}


long Window::retire()
{
    assert(load <= depth);

    if (load == 0) return 0;

    int retired = 0;
    while (load > 0 && retired < ipc) {
        if (!ready_list.at(tail))
            break;

        tail = (tail + 1) % depth;
        load--;
        retired++;
    }

    return retired;
}


void Window::set_ready(long addr, int mask, ulong sector_bits = 0UL)
{
    if (load == 0) return;

    for (int i = 0; i < load; i++) {
        int index = (tail + i) % depth;

        if ((addr_list.at(index) & mask) == (addr & mask))
        {
          // printf("Masking wait list addr 0x%lx sectors 0x%lx -- incoming sectors 0x%lx\n", (addr_list.at(index) & mask), sector_list.at(index), sector_bits);
          sector_list.at(index) &= (~sector_bits);
        }

        if ((((addr_list.at(index) & mask) == (addr & mask)) && sector_list.at(index) == 0UL) || (addr_list.at(index) == -1))
        {
          ready_list.at(index) = true;
        }
                    

        /*
        if (
            ( 
              ((addr_list.at(index) & mask) == (addr & mask))
              && (sector_list.at(index) == sector_bits)
            )
            || (addr_list.at(index) == -1)
           )
           {
             //printf("Window::SetReady addr %ld sector_bits %ld %s\n", addr, sector_bits, addr_list.at(index) == -1 ? "BUBBLE" : "");
             ready_list.at(index) = true;
           }
        // */
    }
}



Trace::Trace(const char* trace_fname) : file(trace_fname), trace_name(trace_fname)
{
    if (!file.good()) {
        std::cerr << "Bad trace file: " << trace_fname << std::endl;
        exit(1);
    }
}

void Trace::populate_pretrace_buffer()
{
    int requests_to_read = pretrace_buffer_size - pretrace_buffer.size();

    for (int i = 0 ; i < requests_to_read ; i++)
    {
      string line;
      getline(file, line);
      if (file.eof()) {
        file.clear();
        file.seekg(0, file.beg);
        getline(file, line);
        //return false;
      }

      string delim = " ";
      size_t pos = 0;

      std::string token;

      pos = line.find(delim);
      token = line.substr(0, pos);
      long inst_addr = std::stoul(token, nullptr, 16);
      line.erase(0, pos + delim.length());
      
      pos = line.find(delim);
      token = line.substr(0, pos);
      long bubble_cnt = std::stoul(token);
      line.erase(0, pos + delim.length());
      
      Request::Type req_type;
      pos = line.find(delim);
      token = line.substr(0, pos);
      if (token[0] == 'R')
          req_type = Request::Type::READ;
      else
          req_type = Request::Type::WRITE; 
      line.erase(0, pos + delim.length());

      pos = line.find(delim);
      token = line.substr(0, pos);
      long req_addr = std::stoul(token, nullptr, 16);
      //printf("RAPrev:%lx RANow:%lx\n", (req_addr & 0x3f), req_addr);
      line.erase(0, pos + delim.length());

      // Memory request's size in bytes
      int req_size;
      // At this point only size is left in line
      req_size = std::stoi(line);

      if (req_size > 64)
      {
        //printf("Ignoring request with size larger than a cache block, sorry...\n");
        i--;
        continue;
      }

      ulong sector_bits = 0;
      ulong req_actual_access = 0;
      if (sector_size > 0 && (sectoredDRAM || DGMS) || (partialActivationDRAM && req_type == Request::Type::WRITE))
      {
        // Break non cache-block-aligned requests into two
        if ((req_addr + req_size) > ((req_addr & ~0x3f) + 64))
        {
          //printf("Gonna divide this request into two: address: 0x%lx size: %d\n", req_addr, req_size);
          // TODO: check if bugs
          ulong first_n_sector_bits = ( 1 << ((((64 - (req_addr & 0x3f))-1)/sector_size) + 1) ) - 1;
          ulong first_sector_bits_offset = ((req_addr & 0x3f)/sector_size);
          ulong first_sector_bits = first_n_sector_bits << first_sector_bits_offset;
          if (sector_size == 8)
            assert(first_sector_bits <= 255 && "Sector bits are unexpectedly large");

          if (!dynamicOn)
            first_sector_bits = 0xff; // retrieve all sectors

          pretrace_buffer.push_back(Entry{inst_addr, bubble_cnt, req_type, (req_addr & ~0x3f), first_sector_bits, (int) (64 - (req_addr & 0x3f)), first_sector_bits});
          //printf("Divided a two-cache-block-spanning request of size %d into two\n", req_size);
          //printf("Req1 - Addr: %lx Sector Bits: %lx\n", req_addr, first_sector_bits);

          // TODO: check if bugs
          ulong second_n_sector_bits = ( 1 << ((req_size - (64 - (req_addr & 0x3f)))/sector_size + 1) ) - 1;
          ulong second_sector_bits_offset = 0;
          ulong second_sector_bits = second_n_sector_bits << second_sector_bits_offset;
          if (sector_size == 8)
            assert(second_sector_bits <= 255 && "Sector bits are unexpectedly large");        


          if (!dynamicOn)
            second_sector_bits = 0xff; // retrieve all sectors

          pretrace_buffer.push_back(Entry{inst_addr, 1, req_type, (req_addr & (~0x3f)) + 64, second_sector_bits, (int) (req_size - (64 - (req_addr & 0x3f))), second_sector_bits});
          //printf("Req2 - Addr: %lx Sector Bits: %lx\n", (req_addr & (~0x3f)) + 64, second_sector_bits);

          i++; // because we inject two requests
          continue;
        }

        // One-hot encoding the number of bits that should be set
        // e.g., if req_size is 8 bytes, and each sector is 8 bytes should be 0x000...001
        ulong n_sector_bits = (1 << (req_size/sector_size == 0 ? 1 : req_size/sector_size)) - 1;
        // Which sectors in the cache block are we going to access, shift sector bits accordingly
        ulong sector_bits_offset = ((req_addr & 0x3f)/sector_size);
        sector_bits = n_sector_bits << sector_bits_offset;
        req_actual_access = sector_bits;

        
        if (sector_size == 8)
          assert(sector_bits <= 255 && "Sector bits are unexpectedly large");
      }
      // If we are not using sectoredDRAM, we should still split requests that span two cache blocks into two requests
      else
      {
        if ((req_addr + req_size) > ((req_addr & ~0x3f) + 64))
        {

          pretrace_buffer.push_back(Entry{inst_addr, bubble_cnt, req_type, (req_addr & ~0x3f), 0, (int) (64 - (req_addr & 0x3f)), 0});
          pretrace_buffer.push_back(Entry{inst_addr, 1, req_type, (req_addr & (~0x3f)) + 64, 0, (int) (req_size - (64 - (req_addr & 0x3f))), 0});
          i++;
          continue;
        }
      }

      if (!dynamicOn)
        sector_bits = 0xff; // retrieve all sectors
      //printf("%ld %ld %d %ld %ld %d\n", inst_addr, bubble_cnt, req_type, req_addr, sector_bits, req_size);
      pretrace_buffer.push_back(Entry{inst_addr, bubble_cnt, req_type, req_addr & ~0x3f, sector_bits, req_size, req_actual_access});      
    }
}

bool Trace::get_unfiltered_request(long& bubble_cnt, long& req_addr, Request::Type& req_type, ulong& sector_bits, int& req_size, long& req_inst_addr, ulong& req_actual_access)
{
    populate_pretrace_buffer();

    Entry request = pretrace_buffer.front(); pretrace_buffer.pop_front();

    bubble_cnt = request.bubble_cnt;
    req_inst_addr = request.req_inst_addr;
    req_addr = request.req_addr;
    req_type = request.req_type;
    req_size = request.req_size;
    req_actual_access = request.req_actual_access;
    sector_bits = request.sector_bits;

    // TODO: insert lookahead predictor here
    if (lookahead_predictor)
    {
        // Traverse pretrace buffer (# of lookahead size -1 entries)
        // Find loads/stores that address the same cache block
        long cache_block_id = req_addr & (~0x3f);
        int coalesce_count = 0;
        for (auto it = pretrace_buffer.cbegin(); it != pretrace_buffer.cend(); ++it) 
        {
            long req_cache_block_id = (*it).req_addr & (~0x3f);
            if (req_cache_block_id == cache_block_id)
            {
                sector_bits |= (*it).sector_bits;
                coalesce_count++;
            }
        }
        //cout << "Lookahead predictor coalesced " << coalesce_count << " entries" << endl; 
    }

    assert(!(sectoredDRAM || DGMS) || sector_bits != 0);

    if (sector_size == 8)
      assert(sector_bits < 256 && "Too many sector bits set by the lookahead predictor");
    //cout << hex << sector_bits << " " << req_addr << " " << bubble_cnt << endl; 
    // TODO: check for trace format?
    return true;
}

bool Trace::get_filtered_request(long& bubble_cnt, long& req_addr, Request::Type& req_type, long& partial_tag)
{
    assert(false && "We simulate a three-level cache hierarchy, so expect everything to be an unfiltered trace");
    static bool has_write = false;
    static long write_addr;
    static long write_partial_tag;
    static int line_num = 0;
    if (has_write){
        bubble_cnt = 0;
        req_addr = write_addr;
        req_type = Request::Type::WRITE;
        partial_tag = write_partial_tag;
        has_write = false;
        return true;
    }
    string line;
    getline(file, line);
    line_num ++;
    if (file.eof() || line.size() == 0) {
        file.clear();
        file.seekg(0, file.beg);
        line_num = 0;

        if(expected_limit_insts == 0) {
            has_write = false;
            return false;
        }
        else { // starting over the input trace file
            getline(file, line);
            line_num++;
        }
    }

    size_t pos, end;
    bubble_cnt = std::stoul(line, &pos, 10); // TODO: (if needed) change this a bit for Sectored DRAM traces

    pos = line.find_first_not_of(' ', pos+1);
    req_addr = stoul(line.substr(pos), &end, 0);
    req_type = Request::Type::READ;

    pos = line.find_first_not_of(' ', pos+end);
    partial_tag = stoul(line.substr(pos), &end, 0);
    assert(partial_tag <= 255);

    pos = line.find_first_not_of(' ', pos+end);
    if (pos != string::npos){
        has_write = true;
        write_addr = stoul(line.substr(pos), &end, 0);
        pos = line.find_first_not_of(' ', pos+end);
        write_partial_tag = stoul(line.substr(pos), NULL, 0);
        assert(write_partial_tag <= 255);

    }
    return true;
}

bool Trace::get_dramtrace_request(long& req_addr, Request::Type& req_type)
{
    string line;
    getline(file, line);
    if (file.eof()) {
        return false;
    }
    size_t pos;
    req_addr = std::stoul(line, &pos, 16);

    pos = line.find_first_not_of(' ', pos+1);

    if (pos == string::npos || line.substr(pos)[0] == 'R')
        req_type = Request::Type::READ;
    else if (line.substr(pos)[0] == 'W')
        req_type = Request::Type::WRITE;
    else assert(false);
    return true;
}
