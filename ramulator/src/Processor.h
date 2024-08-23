#ifndef __PROCESSOR_H
#define __PROCESSOR_H

#include "Cache.h"
#include "Config.h"
#include "Memory.h"
#include "Request.h"
#include "Statistics.h"
#include <iostream>
#include <vector>
#include <deque>
#include <fstream>
#include <string>
#include <ctype.h>
#include <functional>

namespace ramulator 
{

class Trace {
public:
    Trace(const char* trace_fname);
    // trace file format 1:
    // [# of bubbles(non-mem instructions)] [read address(dec or hex)] <optional: write address(evicted cacheline)>
    bool get_unfiltered_request(long& bubble_cnt, long& req_addr, Request::Type& req_type, ulong& sector_bits, int& req_size, long& inst_addr, ulong& req_actual_access);
    bool get_filtered_request(long& bubble_cnt, long& req_addr, Request::Type& req_type, long& partial_tag);
    // trace file format 2:
    // [address(hex)] [R/W]
    bool get_dramtrace_request(long& req_addr, Request::Type& req_type);

    void populate_pretrace_buffer();
    bool dynamicOn = false;

    long expected_limit_insts = 0;
    ulong sector_size = 0;
    bool sectoredDRAM = false;
    bool DGMS = false;
    bool partialActivationDRAM = false;
    int pretrace_buffer_size = 1;
    bool lookahead_predictor = false;

    typedef struct 
    {
        long req_inst_addr;
        long bubble_cnt;
        Request::Type req_type;
        long req_addr;
        ulong sector_bits;
        int req_size;
        ulong req_actual_access;
    } Entry;
    
    std::deque<Entry> pretrace_buffer;
private:

    std::ifstream file;
    std::string trace_name;
};


class Window {
public:
    int ipc = 4;
    int depth = 128;

    Window() : ready_list(depth), addr_list(depth, -1), sector_list(depth, 0) {}
    bool is_full();
    bool is_empty();
    void insert(bool ready, long addr, ulong sectors);
    long retire();
    void set_ready(long addr, int mask, ulong sector_bits);
    int size();
    void dump();

    std::vector<bool> ready_list;
    std::vector<long> addr_list;
    std::vector<ulong> sector_list;
    int tail = 0;
private:
    int load = 0;
    int head = 0;
};


class Core {
public:
    static constexpr double baseline_core_dynamic_power = 8.7066375; //from mcpat, use areapower.py to generate
    static constexpr double sectored_core_dynamic_power = 8.938317685613775; //from mcpat, use areapower.py to generate

    long clk = 0;
    long retired = 0;
    int id = 0;
    function<bool(Request)> send;
    long long clk_per_sec;
    bool dynamicOn = false;

    void traceDynamicOn();
    void traceDynamicOff();

    Core(const Config& configs, int coreid,
        const char* trace_fname,
        function<bool(Request)> send_next, Cache* llc,
        std::shared_ptr<CacheSystem> cachesys, MemoryBase& memory);
    void tick();
    void receive(Request& req);
    void reset_stats();
    double calc_ipc();
    void calc_dyn_energy();
    bool finished();
    
    bool has_reached_limit();
    long get_insts(); // the number of the instructions issued to the core
    void dump_window();
    function<void(Request&)> callback;

    bool no_core_caches = true;
    bool no_shared_cache = true;
    int l1_size = 1 << 15;
    int l1_assoc = 1 << 3;
    int l1_blocksz = 1 << 6;
    int l1_mshr_num = 16;

    int l2_size = 1 << 18;
    int l2_assoc = 1 << 3;
    int l2_blocksz = 1 << 6;
    int l2_mshr_num = 16;
    std::vector<std::shared_ptr<Cache>> caches;
    Cache* llc;

    int sector_size = 0;
    bool sectoredDRAM = false;
    bool DGMS = false;
    bool partialActivationDRAM = false;
    bool lookahead_predictor = false;

    ScalarStat record_cycs;
    ScalarStat record_insts;
    ScalarStat dynamic_energy;

    long expected_limit_insts;
    // This is set true iff expected number of instructions has been executed or all instructions are executed.
    bool reached_limit = false;
    Window window;

private:
    Trace trace;

    long bubble_cnt;
    long req_addr = -1;
    ulong req_actual_access = -1;
    int  req_size = -1;
    long  req_inst_addr = -1;
    ulong sector_bits = 0;
    long partial_tag;
    long write_partial_tag;
    Request::Type req_type;
    bool more_reqs;
    long last = 0;

    Cache* first_level_cache = nullptr;

    ScalarStat memory_access_cycles;
    ScalarStat cpu_inst;
    MemoryBase& memory;
};

class Processor {
public:
    static constexpr double static_power = 32.0109;
    Processor(const Config& configs, vector<const char*> trace_list,
        function<bool(Request)> send, MemoryBase& memory);
    void tick();
    void receive(Request& req);
    void reset_stats();
    // To correctly account for L3 used block statistics

    bool finished();
    bool has_reached_limit();
    long get_insts(); // the total number of instructions issued to all cores
    void finish();
    void evictLLC();

    void turnSectorDRAMOn();
    void turnSectorDRAMOff();

    std::vector<std::unique_ptr<Core>> cores;
    std::vector<double> ipcs;
    double ipc = 0;

    // When early_exit is true, the simulation exits when the earliest trace finishes.
    bool early_exit;

    bool no_core_caches = true;
    bool no_shared_cache = true;

    int sector_size = 0;
    bool sectoredDRAM = false;
    bool DGMS = false;
    bool partialActivationDRAM = false;

    int l3_size = 1 << 23;
    int l3_assoc = 1 << 3;
    int l3_blocksz = 1 << 6;
    int mshr_per_bank = 16;

    std::shared_ptr<CacheSystem> cachesys;
    Cache llc;

    ScalarStat cpu_cycles;
    ScalarStat processor_energy;
};

}
#endif /* __PROCESSOR_H */
