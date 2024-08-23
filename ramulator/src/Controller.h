#ifndef __CONTROLLER_H
#define __CONTROLLER_H

#include <cassert>
#include <cstdio>
#include <deque>
#include <fstream>
#include <list>
#include <string>
#include <vector>
#include <map>
#include <queue>

#include "Config.h"
#include "DRAM.h"
#include "Refresh.h"
#include "Request.h"
#include "Scheduler.h"
#include "Statistics.h"
#include "libdrampower/LibDRAMPower.h"
#include "xmlparser/MemSpecParser.h"


using namespace std;

namespace ramulator
{
class Processor;

    extern bool warmup_complete;

template <typename T>
class Controller
{
protected:
    // For counting bandwidth
    ScalarStat read_transaction_bytes;
    ScalarStat write_transaction_bytes;

    ScalarStat row_hits;
    ScalarStat row_misses;
    ScalarStat sector_misses;
    ScalarStat row_conflicts;
    VectorStat read_row_hits;
    VectorStat read_row_misses;
    VectorStat read_sector_misses;
    VectorStat read_row_conflicts;
    VectorStat write_row_hits;
    VectorStat write_row_misses;
    VectorStat write_sector_misses;
    VectorStat write_row_conflicts;
    ScalarStat useless_activates;

    ScalarStat read_latency_avg;
    ScalarStat read_latency_sum;

    ScalarStat req_queue_length_avg;
    ScalarStat req_queue_length_sum;
    ScalarStat read_req_queue_length_avg;
    ScalarStat read_req_queue_length_sum;
    ScalarStat write_req_queue_length_avg;
    ScalarStat write_req_queue_length_sum;

    ScalarStat faw_penalty_cycles;

#ifndef INTEGRATED_WITH_GEM5
    VectorStat record_read_hits;
    VectorStat record_read_misses;
    VectorStat record_read_conflicts;
    VectorStat record_write_hits;
    VectorStat record_write_misses;
    VectorStat record_write_conflicts;
#endif

    // DRAMPower
    VectorStat dpower_act_energy, dpower_pre_energy, dpower_rd_energy, dpower_wr_energy, dpower_ref_energy, dpower_refpb_energy;
    VectorStat dpower_act_stdby_energy, dpower_pre_stdby_energy;
    VectorStat dpower_io_term_energy;
    VectorStat dpower_total_energy, dpower_avg_power;


public:
    /* Member Variables */
    long clk = 0;
    DRAM<T>* channel;
    Processor* proc;

    Scheduler<T>* scheduler;  // determines the highest priority request whose commands will be issued
    RowPolicy<T>* rowpolicy;  // determines the row-policy (e.g., closed-row vs. open-row)
    RowTable<T>* rowtable;  // tracks metadata about rows (e.g., which are open and for how long)
    Refresh<T>* refresh;

    float rolling_avg_tx = 0;
    int samples_tx = 0;

    struct Queue {
        list<Request> q;
        unsigned int max = 32;
        unsigned int size() {return q.size();}
    };

    Queue readq;  // queue for read requests
    Queue writeq;  // queue for write requests
    Queue actq; // read and write requests for which activate was issued are moved to 
                   // actq, which has higher priority than readq and writeq.
                   // This is an optimization
                   // for avoiding useless activations (i.e., PRECHARGE
                   // after ACTIVATE w/o READ of WRITE command)
    Queue otherq;  // queue for all "other" requests (e.g., refresh)

    deque<Request> pending;  // read requests that are about to receive data from DRAM
    bool write_mode = false;  // whether write requests should be prioritized over reads
    float wr_high_watermark = 0.8f; // threshold for switching to write mode
    float wr_low_watermark = 0.2f; // threshold for switching back to read mode
    //long refreshed = 0;  // last time refresh requests were generated

    /* Command trace for DRAMPower 3.1 */
    string cmd_trace_prefix = "cmd-trace-";
    vector<ofstream> cmd_trace_files;
    bool record_cmd_trace = false;
    /* Commands to stdout */
    bool print_cmd_trace = false;

    /* Sectored DRAM */
    bool sectoredDRAM = false;
    bool dynamicOn = false;
    bool sectoredDRAMSALP = false;
    int sector_size = 0;
    multimap<long int, Request> parallelReads;
    long int waitAddress = -1;
    bool debug = false;

    int tFAW_budget = 0;

    std::vector<libDRAMPower> dpower;
    bool dpower_is_reset = false;

    bool halfDRAM = false;
    bool fgDRAM = false;
    bool partialActivationDRAM = false;
    bool DGMS = false;
    bool burstChopDRAM = false;

    bool dynamic_policy = false;

    typedef struct 
    {
        long tick;
        int sectors;
    } faw_entry;

    queue <faw_entry> faw_queue;

    /* Constructor */
    Controller(const Config& configs, DRAM<T>* channel) :
        channel(channel),
        scheduler(new Scheduler<T>(this)),
        rowpolicy(new RowPolicy<T>(this)),
        rowtable(new RowTable<T>(this)),
        refresh(new Refresh<T>(this)),
        cmd_trace_files(channel->children.size())
    {
        sectoredDRAM = configs.is_sectoredDRAM();

        halfDRAM = configs.is_halfDRAM();
        fgDRAM = configs.is_fgDRAM();
        partialActivationDRAM = configs.is_partialActivationDRAM();

        sectoredDRAMSALP = configs.is_parallelization_enabled();
        burstChopDRAM = configs.is_burstChopDRAM();

        DGMS = configs.is_DGMS();
        assert(!sectoredDRAMSALP && "not guaranteed to work yet");
        sector_size = configs.get_sector_size();

        // Yanked from Hassan
        // Initialize DRAM Power
        DRAMPower::MemorySpecification memSpec(DRAMPower::MemSpecParser::getMemSpecFromXML(configs.get_dpower_config_path()));

        // a separate DRAMPower object per rank
        dpower.reserve((uint32_t)channel->spec->org_entry.count[int(T::Level::Rank)]);
        for (uint32_t rank_id = 0; rank_id < (uint32_t)channel->spec->org_entry.count[int(T::Level::Rank)]; rank_id++)
        {
            dpower.emplace_back(memSpec, true); // always simulate I/O termination
            if (halfDRAM)
                dpower[rank_id].enableHalfDRAM();
        }

        // CB size/sector_size = # of sectors
        // multiply by four because we can issue up 
        // to four activates within this window
        if (sectoredDRAM || partialActivationDRAM || fgDRAM || halfDRAM)
            tFAW_budget = (64/sector_size) * 4;
        else
            tFAW_budget = 4;


        record_cmd_trace = configs.record_cmd_trace();
        print_cmd_trace = configs.print_cmd_trace();
        if (record_cmd_trace){
            if (configs["cmd_trace_prefix"] != "") {
              cmd_trace_prefix = configs["cmd_trace_prefix"];
            }
            string prefix = cmd_trace_prefix + "chan-" + to_string(channel->id) + "-rank-";
            string suffix = ".cmdtrace";
            for (unsigned int i = 0; i < channel->children.size(); i++)
                cmd_trace_files[i].open(prefix + to_string(i) + suffix);
        }

        dynamic_policy = configs.is_dynamic_policy();

        // regStats

        row_hits
            .name("row_hits_channel_"+to_string(channel->id))
            .desc("Number of row hits per channel per core")
            .precision(0)
            ;
        row_misses
            .name("row_misses_channel_"+to_string(channel->id))
            .desc("Number of row misses per channel per core")
            .precision(0)
            ;
            
        sector_misses
            .name("sector_misses_channel_"+to_string(channel->id))
            .desc("Number of sector misses per channel per core")
            .precision(0)
            ;
        row_conflicts
            .name("row_conflicts_channel_"+to_string(channel->id))
            .desc("Number of row conflicts per channel per core")
            .precision(0)
            ;

        read_row_hits
            .init(configs.get_core_num())
            .name("read_row_hits_channel_"+to_string(channel->id))
            .desc("Number of row hits for read requests per channel per core")
            .precision(0)
            ;
        read_row_misses
            .init(configs.get_core_num())
            .name("read_row_misses_channel_"+to_string(channel->id))
            .desc("Number of row misses for read requests per channel per core")
            .precision(0)
            ;
        read_sector_misses
            .init(configs.get_core_num())
            .name("read_sector_misses_channel_"+to_string(channel->id))
            .desc("Number of sector misses for read requests per channel per core")
            .precision(0)
            ;   
        read_row_conflicts
            .init(configs.get_core_num())
            .name("read_row_conflicts_channel_"+to_string(channel->id))
            .desc("Number of row conflicts for read requests per channel per core")
            .precision(0)
            ;

        write_row_hits
            .init(configs.get_core_num())
            .name("write_row_hits_channel_"+to_string(channel->id))
            .desc("Number of row hits for write requests per channel per core")
            .precision(0)
            ;
        write_row_misses
            .init(configs.get_core_num())
            .name("write_row_misses_channel_"+to_string(channel->id))
            .desc("Number of row misses for write requests per channel per core")
            .precision(0)
            ;
        write_sector_misses
            .init(configs.get_core_num())
            .name("write_sector_misses_channel_"+to_string(channel->id))
            .desc("Number of sector misses for write requests per channel per core")
            .precision(0)
            ;   
    
        write_row_conflicts
            .init(configs.get_core_num())
            .name("write_row_conflicts_channel_"+to_string(channel->id))
            .desc("Number of row conflicts for write requests per channel per core")
            .precision(0)
            ;

        useless_activates
            .name("useless_activates_"+to_string(channel->id))
            .desc("Number of useless activations. E.g, ACT -> PRE w/o RD or WR")
            .precision(0)
            ;

        read_transaction_bytes
            .name("read_transaction_bytes_"+to_string(channel->id))
            .desc("The total byte of read transaction per channel")
            .precision(0)
            ;
        write_transaction_bytes
            .name("write_transaction_bytes_"+to_string(channel->id))
            .desc("The total byte of write transaction per channel")
            .precision(0)
            ;

        read_latency_sum
            .name("read_latency_sum_"+to_string(channel->id))
            .desc("The memory latency cycles (in memory time domain) sum for all read requests in this channel")
            .precision(0)
            ;
        read_latency_avg
            .name("read_latency_avg_"+to_string(channel->id))
            .desc("The average memory latency cycles (in memory time domain) per request for all read requests in this channel")
            .precision(6)
            ;

        req_queue_length_sum
            .name("req_queue_length_sum_"+to_string(channel->id))
            .desc("Sum of read and write queue length per memory cycle per channel.")
            .precision(0)
            ;
        req_queue_length_avg
            .name("req_queue_length_avg_"+to_string(channel->id))
            .desc("Average of read and write queue length per memory cycle per channel.")
            .precision(6)
            ;

        read_req_queue_length_sum
            .name("read_req_queue_length_sum_"+to_string(channel->id))
            .desc("Read queue length sum per memory cycle per channel.")
            .precision(0)
            ;
        read_req_queue_length_avg
            .name("read_req_queue_length_avg_"+to_string(channel->id))
            .desc("Read queue length average per memory cycle per channel.")
            .precision(6)
            ;

        write_req_queue_length_sum
            .name("write_req_queue_length_sum_"+to_string(channel->id))
            .desc("Write queue length sum per memory cycle per channel.")
            .precision(0)
            ;
        write_req_queue_length_avg
            .name("write_req_queue_length_avg_"+to_string(channel->id))
            .desc("Write queue length average per memory cycle per channel.")
            .precision(6)
            ;

        faw_penalty_cycles
            .name("faw_penalty_cycles_"+to_string(channel->id))
            .desc("Total number of cycles wasted because FAW was unsatisfied")
            .precision(0)
            ;

#ifndef INTEGRATED_WITH_GEM5
        record_read_hits
            .init(configs.get_core_num())
            .name("record_read_hits")
            .desc("record read hit count for this core when it reaches request limit or to the end")
            ;

        record_read_misses
            .init(configs.get_core_num())
            .name("record_read_misses")
            .desc("record_read_miss count for this core when it reaches request limit or to the end")
            ;

        record_read_conflicts
            .init(configs.get_core_num())
            .name("record_read_conflicts")
            .desc("record read conflict count for this core when it reaches request limit or to the end")
            ;

        record_write_hits
            .init(configs.get_core_num())
            .name("record_write_hits")
            .desc("record write hit count for this core when it reaches request limit or to the end")
            ;

        record_write_misses
            .init(configs.get_core_num())
            .name("record_write_misses")
            .desc("record write miss count for this core when it reaches request limit or to the end")
            ;

        record_write_conflicts
            .init(configs.get_core_num())
            .name("record_write_conflicts")
            .desc("record write conflict for this core when it reaches request limit or to the end")
            ;
#endif

        // DRAMPower
        dpower_act_energy
            .init((uint32_t)channel->spec->org_entry.count[int(T::Level::Rank)])
            .name("dpower_act_energy_rank"+to_string(channel->id))
            .desc("ACT command energy (per rank) in mJ.")
            .precision(3);

        dpower_pre_energy
            .init((uint32_t)channel->spec->org_entry.count[int(T::Level::Rank)])
            .name("dpower_pre_energy_rank"+to_string(channel->id))
            .desc("PRE command energy (per rank) in mJ.")
            .precision(3);

        dpower_rd_energy
            .init((uint32_t)channel->spec->org_entry.count[int(T::Level::Rank)])
            .name("dpower_rd_energy_rank"+to_string(channel->id))
            .desc("READ command energy (per rank) in mJ.")
            .precision(3);

        dpower_wr_energy
            .init((uint32_t)channel->spec->org_entry.count[int(T::Level::Rank)])
            .name("dpower_wr_energy_rank"+to_string(channel->id))
            .desc("WRITE command energy (per rank) in mJ.")
            .precision(3);

        dpower_ref_energy
            .init((uint32_t)channel->spec->org_entry.count[int(T::Level::Rank)])
            .name("dpower_ref_energy_rank"+to_string(channel->id))
            .desc("REFRESH command energy (per rank) in mJ.")
            .precision(3);

        dpower_refpb_energy
            .init((uint32_t)channel->spec->org_entry.count[int(T::Level::Rank)])
            .name("dpower_refpb_energy_rank"+to_string(channel->id))
            .desc("REFRESHpb command energy (per rank) in mJ.")
            .precision(3);

        dpower_act_stdby_energy
            .init((uint32_t)channel->spec->org_entry.count[int(T::Level::Rank)])
            .name("dpower_act_stdby_energy_rank"+to_string(channel->id))
            .desc("ACT standby energy (per rank) in mJ.")
            .precision(3);

        dpower_pre_stdby_energy
            .init((uint32_t)channel->spec->org_entry.count[int(T::Level::Rank)])
            .name("dpower_pre_stdby_energy_rank"+to_string(channel->id))
            .desc("PRE standby energy (per rank) in mJ.")
            .precision(3);

        dpower_io_term_energy
            .init((uint32_t)channel->spec->org_entry.count[int(T::Level::Rank)])
            .name("dpower_io_term_energy_rank"+to_string(channel->id))
            .desc("Total IO/termination energy (per rank) in mJ.")
            .precision(3);

        dpower_total_energy
            .init((uint32_t)channel->spec->org_entry.count[int(T::Level::Rank)])
            .name("dpower_total_energy_rank"+to_string(channel->id))
            .desc("Total DRAM energy (per rank) in mJ.")
            .precision(3);

        dpower_avg_power
            .init((uint32_t)channel->spec->org_entry.count[int(T::Level::Rank)])
            .name("dpower_avg_power_rank"+to_string(channel->id))
            .desc("Average DRAM power (per rank) in mW.")
            .precision(3);

    }

    ~Controller(){
        delete scheduler;
        delete rowpolicy;
        delete rowtable;
        delete channel;
        delete refresh;
        for (auto& file : cmd_trace_files)
            file.close();
        cmd_trace_files.clear();
    }

    void setProc(Processor* proc) {this->proc = proc;}

    void finish(long read_req, long dram_cycles) {
      read_latency_avg = read_latency_sum.value() / read_req;
      req_queue_length_avg = req_queue_length_sum.value() / dram_cycles;
      read_req_queue_length_avg = read_req_queue_length_sum.value() / dram_cycles;
      write_req_queue_length_avg = write_req_queue_length_sum.value() / dram_cycles;
      // call finish function of each channel
      channel->finish(dram_cycles);
      update_DPower(true);
    }

void update_DPower(const bool finish = false) {
        for (uint32_t rank_id = 0; rank_id < (uint32_t)channel->spec->org_entry.count[int(T::Level::Rank)]; rank_id++) {
            dpower[rank_id].calcWindowEnergy(clk);

            dpower_act_energy[rank_id] += dpower[rank_id].getEnergy().act_energy/1000000000; // converting pJ to mJ
            dpower_pre_energy[rank_id] += dpower[rank_id].getEnergy().pre_energy/1000000000;
            dpower_rd_energy[rank_id] += dpower[rank_id].getEnergy().read_energy/1000000000;
            dpower_wr_energy[rank_id] += dpower[rank_id].getEnergy().write_energy/1000000000;
            dpower_ref_energy[rank_id] += dpower[rank_id].getEnergy().ref_energy/1000000000;

            auto& refpb_energy = dpower[rank_id].getEnergy().refb_energy_banks;
            dpower_refpb_energy[rank_id] += std::accumulate(refpb_energy.begin(), refpb_energy.end(), 0)/1000000000;

            dpower_act_stdby_energy[rank_id] += dpower[rank_id].getEnergy().act_stdby_energy/1000000000;
            dpower_pre_stdby_energy[rank_id] += dpower[rank_id].getEnergy().pre_stdby_energy/1000000000;

            dpower_io_term_energy[rank_id] += dpower[rank_id].getEnergy().io_term_energy/1000000000;

            dpower_total_energy[rank_id] += dpower[rank_id].getEnergy().window_energy/1000000000;

            if (finish) {
                dpower[rank_id].calcEnergy();
                dpower_avg_power[rank_id] = dpower[rank_id].getPower().average_power;
            }
        }
    }

    void discard_DPowerWindow() {
        for (uint32_t rank_id = 0; rank_id < (uint32_t)channel->spec->org_entry.count[int(T::Level::Rank)]; rank_id++)
            dpower[rank_id].calcWindowEnergy(clk);
    }

    /* Member Functions */
    Queue& get_queue(Request::Type type)
    {
        switch (int(type)) {
            case int(Request::Type::READ):
            case int(Request::Type::PREFETCH): return readq;
            case int(Request::Type::WRITE): return writeq;
            default: return otherq;
        }
    }

    bool can_schedule(Request::Type type)
    {
        Queue& queue = get_queue(type);
        if (queue.max == queue.size())
            return false;   
        return true;     
    }

    bool enqueue(Request& req)
    {
        Queue& queue = get_queue(req.type);
        if (queue.max == queue.size())
            return false;

        // sector bits used by the controller
        req.sector_bits[4] = req.sector_bits[3];

        if (sectoredDRAM)
        {
            // try to make earlier requests open later requests' sectors too
            for (Request& existing_req : queue.q)
            {
                if ((req.addr_vec[int(T::Level::Rank)] == existing_req.addr_vec[int(T::Level::Rank)]) &&
                    (req.addr_vec[int(T::Level::BankGroup)] == existing_req.addr_vec[int(T::Level::BankGroup)]) &&
                    (req.addr_vec[int(T::Level::Bank)] == existing_req.addr_vec[int(T::Level::Bank)]) &&
                    (req.addr_vec[int(T::Level::Row)] == existing_req.addr_vec[int(T::Level::Row)]))
                existing_req.sector_bits[4] |= req.sector_bits[4];
            }
        }

        req.arrive = clk;
        queue.q.push_back(req);

        if (sectoredDRAM && (sector_size == 8) && (req.type != Request::Type::REFRESH))
            assert(req.sector_bits[3] < 256);

        // shortcut for read requests, if a write to same addr exists
        // necessary for coherence
        if ((req.type == Request::Type::READ || req.type == Request::Type::PREFETCH) && find_if(writeq.q.begin(), writeq.q.end(),
                [req](Request& wreq){ return req.addr == wreq.addr;}) != writeq.q.end()){
            req.depart = clk + 1;
            pending.push_back(req);
            readq.q.pop_back();
        }
        return true;
    }

    int rolling_sum_queue_length = 0;

    

    inline int count_activated_sectors(ulong sector_bits){
        return __builtin_popcountll(sector_bits);
    }

    bool is_ready(list<Request>::iterator req)
    {
        typename T::Command cmd = get_first_cmd(req);
        return channel->check(cmd, req->addr_vec.data(), clk);
    }

    bool is_ready(typename T::Command cmd, const vector<int>& addr_vec)
    {
        return channel->check(cmd, addr_vec.data(), clk);
    }

    bool is_row_hit(list<Request>::iterator req)
    {
        // cmd must be decided by the request type, not the first cmd
        typename T::Command cmd = channel->spec->translate[int(req->type)];
        return channel->check_row_hit(cmd, req->addr_vec.data(), req->sector_bits[3]);
    }

    bool is_sector_miss(list<Request>::iterator req)
    {
        // cmd must be decided by the request type, not the first cmd
        typename T::Command cmd = channel->spec->translate[int(req->type)];
        return channel->check_sector_miss(cmd, req->addr_vec.data(), req->sector_bits[3]);
    }

    bool is_row_hit(typename T::Command cmd, const vector<int>& addr_vec)
    {
        return channel->check_row_hit(cmd, addr_vec.data(), 0UL);
    }

    bool is_row_open(list<Request>::iterator req)
    {
        // cmd must be decided by the request type, not the first cmd
        typename T::Command cmd = channel->spec->translate[int(req->type)];
        return channel->check_row_open(cmd, req->addr_vec.data());
    }

    bool is_row_open(typename T::Command cmd, const vector<int>& addr_vec)
    {
        return channel->check_row_open(cmd, addr_vec.data());
    }

    void update_temp(ALDRAM::Temp current_temperature)
    {
    }

    // For telling whether this channel is busying in processing read or write
    bool is_active() {
      return (channel->cur_serving_requests > 0);
    }

    // For telling whether this channel is under refresh
    bool is_refresh() {
      return clk <= channel->end_of_refreshing;
    }

    void set_high_writeq_watermark(const float watermark) {
       wr_high_watermark = watermark; 
    }

    void set_low_writeq_watermark(const float watermark) {
       wr_low_watermark = watermark;
    }

    void record_core(int coreid) {
#ifndef INTEGRATED_WITH_GEM5
      record_read_hits[coreid] = read_row_hits[coreid];
      record_read_misses[coreid] = read_row_misses[coreid];
      record_read_conflicts[coreid] = read_row_conflicts[coreid];
      record_write_hits[coreid] = write_row_hits[coreid];
      record_write_misses[coreid] = write_row_misses[coreid];
      record_write_conflicts[coreid] = write_row_conflicts[coreid];
#endif
    }

private:
    typename T::Command get_first_cmd(list<Request>::iterator req)
    {
        typename T::Command cmd = channel->spec->translate[int(req->type)];
        return channel->decode(cmd, req->addr_vec.data(), req->sector_bits[3]); // Hint to Nisa: this will need to change once we impl. sector bit accumulation technique
    }

    // upgrade to an autoprecharge command
    void cmd_issue_autoprecharge(typename T::Command& cmd,
                                            const vector<int>& addr_vec) {

        // currently, autoprecharge is only used with closed row policy
        if(channel->spec->is_accessing(cmd) && rowpolicy->type == RowPolicy<T>::Type::ClosedAP) {
            // check if it is the last request to the opened row
            Queue* queue = write_mode ? &writeq : &readq;

            auto begin = addr_vec.begin();
            vector<int> rowgroup(begin, begin + int(T::Level::Row) + 1);

			int num_row_hits = 0;

            for (auto itr = queue->q.begin(); itr != queue->q.end(); ++itr) {
                if (is_row_hit(itr)) { 
                    auto begin2 = itr->addr_vec.begin();
                    vector<int> rowgroup2(begin2, begin2 + int(T::Level::Row) + 1);
                    if(rowgroup == rowgroup2)
                        num_row_hits++;
                }
            }

            if(num_row_hits == 0) {
                Queue* queue = &actq;
                for (auto itr = queue->q.begin(); itr != queue->q.end(); ++itr) {
                    if (is_row_hit(itr)) {
                        auto begin2 = itr->addr_vec.begin();
                        vector<int> rowgroup2(begin2, begin2 + int(T::Level::Row) + 1);
                        if(rowgroup == rowgroup2)
                            num_row_hits++;
                    }
                }
            }

            assert(num_row_hits > 0); // The current request should be a hit, 
                                      // so there should be at least one request 
                                      // that hits in the current open row
            if(num_row_hits == 1) {
                if(cmd == T::Command::RD)
                    cmd = T::Command::RDA;
                else if (cmd == T::Command::WR)
                    cmd = T::Command::WRA;
                else
                    assert(false && "Unimplemented command type.");
            }
        }

    }


    // Yanked from Hassan's SMDRAM implementation
    void issueDPowerCommand(const typename T::Command cmd, const uint32_t rank_id, const uint32_t gbid, ulong sector_bits) {

        DRAMPower::MemCommand::cmds dpower_cmd = DRAMPower::MemCommand::NOP;
        switch(cmd) {
            case T::Command::ACT: {
                dpower_cmd = DRAMPower::MemCommand::PARTIAL_ACT;
                assert(sector_bits > 0 || !sectoredDRAM &&  "Activating no sectors????");
                break;
            }
            case T::Command::PRE: {
                dpower_cmd = DRAMPower::MemCommand::PRE;
                break;
            }
            case T::Command::PREA: {
                dpower_cmd = DRAMPower::MemCommand::PREA;
                break;
            }
            case T::Command::RD: {
                dpower_cmd = DRAMPower::MemCommand::RD;
                break;
            }
            case T::Command::RDA: {
                dpower_cmd = DRAMPower::MemCommand::RDA;
                break;
            }
            case T::Command::WR: {
                dpower_cmd = DRAMPower::MemCommand::WR;
                break;
            }
            case T::Command::WRA: {
                dpower_cmd = DRAMPower::MemCommand::WRA;
                break;
            }
            case T::Command::REF: {
                dpower_cmd = DRAMPower::MemCommand::REF;
                break;
            }
            // TODO: implement ACT_NACK and NACK'ed ACT commands

            default: {
                assert(false && "ERROR: Unimplemented DRAMPower command!");
            }
        }

        if ((dpower_cmd == DRAMPower::MemCommand::RD || dpower_cmd == DRAMPower::MemCommand::WR) && fgDRAM)
            for (int i = 0 ; i < 64/sector_size ; i++)
                dpower[rank_id].doCommand(dpower_cmd, gbid, clk + i * channel->spec->get_nRRDL() / (64/sector_size), sector_bits);
        else
            dpower[rank_id].doCommand(dpower_cmd, gbid, clk, sector_bits);
    }


    void issue_cmd(typename T::Command cmd, const vector<int>& addr_vec, ulong sector_bits)
    {
        // TODO: This can cause problems when we are evaluating related work
        if (!(sectoredDRAM || partialActivationDRAM || fgDRAM || halfDRAM))
            sector_bits = 0;

        cmd_issue_autoprecharge(cmd, addr_vec);
        assert(is_ready(cmd, addr_vec));
        channel->update(cmd, addr_vec.data(), clk, sector_bits);

        if (fgDRAM)
            sector_bits = 1; // always opens and reads from a single sector

        if (halfDRAM)
            sector_bits = (1 << (64/sector_size/2)) - 1;

        issueDPowerCommand(cmd, addr_vec[int(T::Level::Rank)], addr_vec[int(T::Level::BankGroup)] * 4 + addr_vec[int(T::Level::Bank)], sector_bits);
 
        if (record_cmd_trace){
            // select rank
            auto& file = cmd_trace_files[addr_vec[1]];
            string& cmd_name = channel->spec->command_name[int(cmd)];
            file<<clk<<','<<cmd_name;
            // TODO bad coding here
            if (cmd_name == "PREA" || cmd_name == "REF")
                file<<endl;
            else{
                int bank_id = addr_vec[int(T::Level::Bank)];
                if (channel->spec->standard_name == "DDR4" || channel->spec->standard_name == "GDDR5")
                    bank_id += addr_vec[int(T::Level::Bank) - 1] * channel->spec->org_entry.count[int(T::Level::Bank)];
                if (cmd_name == "PRA") 
                    file << ","<<bank_id << "," << sector_bits << endl;
                else
                    file<<','<<bank_id<<endl;
            }
        }
        if (print_cmd_trace){
            printf("%5s %10ld:", channel->spec->command_name[int(cmd)].c_str(), clk);
            for (int lev = 0; lev < int(T::Level::MAX); lev++)
                printf(" %5d", addr_vec[lev]);
            printf("\n");
        }


        if(cmd == T::Command::PRE){
            if(rowtable->get_hits(addr_vec, true) == 0){
                useless_activates++;
            }
        }


        rowtable->update(cmd, addr_vec, clk);

    }
    vector<int> get_addr_vec(typename T::Command cmd, list<Request>::iterator req){
        return req->addr_vec;
    }

    public:
    void tick(bool can_schedule);
};
} /*namespace ramulator*/

#endif /*__CONTROLLER_H*/
