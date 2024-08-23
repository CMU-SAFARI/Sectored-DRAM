#ifdef MUSTAFA
#include "Controller.h"
#include "SALP.h"
#include "ALDRAM.h"
#include "TLDRAM.h"

using namespace ramulator;

namespace ramulator
{

static vector<int> get_offending_subarray(DRAM<SALP>* channel, vector<int> & addr_vec){
    int sa_id = 0;
    auto rank = channel->children[addr_vec[int(SALP::Level::Rank)]];
    auto bank = rank->children[addr_vec[int(SALP::Level::Bank)]];
    auto sa = bank->children[addr_vec[int(SALP::Level::SubArray)]];
    for (auto sa_other : bank->children)
        if (sa != sa_other && sa_other->state == SALP::State::Opened){
            sa_id = sa_other->id;
            break;
        }
    vector<int> offending = addr_vec;
    offending[int(SALP::Level::SubArray)] = sa_id;
    offending[int(SALP::Level::Row)] = -1;
    return offending;
}


template <>
vector<int> Controller<SALP>::get_addr_vec(SALP::Command cmd, list<Request>::iterator req){
    if (cmd == SALP::Command::PRE_OTHER)
        return get_offending_subarray(channel, req->addr_vec);
    else
        return req->addr_vec;
}


template <>
bool Controller<SALP>::is_ready(list<Request>::iterator req){
    SALP::Command cmd = get_first_cmd(req);
    if (cmd == SALP::Command::PRE_OTHER){

        vector<int> addr_vec = get_offending_subarray(channel, req->addr_vec);
        return channel->check(cmd, addr_vec.data(), clk);
    }
    else return channel->check(cmd, req->addr_vec.data(), clk);
}

template <>
void Controller<ALDRAM>::update_temp(ALDRAM::Temp current_temperature){
    channel->spec->aldram_timing(current_temperature);
}


template <>
void Controller<TLDRAM>::tick(){
    clk++;
    req_queue_length_sum += readq.size() + writeq.size();
    read_req_queue_length_sum += readq.size();
    write_req_queue_length_sum += writeq.size();

    /*** 1. Serve completed reads ***/
    if (pending.size()) {
        Request& req = pending[0];
        if (req.depart <= clk) {
          if (req.depart - req.arrive > 1) {
                  read_latency_sum += req.depart - req.arrive;
                  channel->update_serving_requests(
                      req.addr_vec.data(), -1, clk);
          }
            req.callback(req);
            pending.pop_front();
        }
    }

    /*** 2. Should we schedule refreshes? ***/
    refresh->tick_ref();

    /*** 3. Should we schedule writes? ***/
    if (!write_mode) {
        // yes -- write queue is almost full or read queue is empty
        if (writeq.size() >= int(0.8 * writeq.max) /*|| readq.size() == 0*/)
            write_mode = true;
    }
    else {
        // no -- write queue is almost empty and read queue is not empty
        if (writeq.size() <= int(0.2 * writeq.max) && readq.size() != 0)
            write_mode = false;
    }

    /*** 4. Find the best command to schedule, if any ***/
    Queue* queue = !write_mode ? &readq : &writeq;
    if (otherq.size())
        queue = &otherq;  // "other" requests are rare, so we give them precedence over reads/writes

    auto req = scheduler->get_head(queue->q);
    if (req == queue->q.end() || !is_ready(req)) {
        // we couldn't find a command to schedule -- let's try to be speculative
        auto cmd = TLDRAM::Command::PRE;
        vector<int> victim = rowpolicy->get_victim(cmd);
        if (!victim.empty()){
            issue_cmd(cmd, victim, 0);
        }
        return;  // nothing more to be done this cycle
    }

    if (req->is_first_command) {
        int coreid = req->coreid;
        req->is_first_command = false;
        if (req->type == Request::Type::READ || req->type == Request::Type::WRITE) {
          channel->update_serving_requests(req->addr_vec.data(), 1, clk);
        }
        int tx = (channel->spec->prefetch_size * channel->spec->channel_width / 8);

        if (req->type == Request::Type::READ) {
            if (is_row_hit(req)) {
                ++read_row_hits[coreid];
                ++row_hits;
            } else if (is_row_open(req)) {
                ++read_row_conflicts[coreid];
                ++row_conflicts;
            } else {
                ++read_row_misses[coreid];
                ++row_misses;
            }
          read_transaction_bytes += tx;
        } else if (req->type == Request::Type::WRITE) {
          if (is_row_hit(req)) {
              ++write_row_hits[coreid];
              ++row_hits;
          } else if (is_row_open(req)) {
              ++write_row_conflicts[coreid];
              ++row_conflicts;
          } else {
              ++write_row_misses[coreid];
              ++row_misses;
          }
          write_transaction_bytes += tx;
        }
    }

    /*** 5. Change a read request to a migration request ***/
    if (req->type == Request::Type::READ) {
        req->type = Request::Type::EXTENSION;
    }

    // issue command on behalf of request
    auto cmd = get_first_cmd(req);
    issue_cmd(cmd, get_addr_vec(cmd, req), 0);

    // check whether this is the last command (which finishes the request)
    if (cmd != channel->spec->translate[int(req->type)])
        return;

    // set a future completion time for read requests
    if (req->type == Request::Type::READ || req->type == Request::Type::EXTENSION) {
        req->depart = clk + channel->spec->read_latency;
        pending.push_back(*req);
    }
    if (req->type == Request::Type::WRITE) {
        channel->update_serving_requests(req->addr_vec.data(), -1, clk);
    }

    // remove request from queue
    queue->q.erase(req);
}

template<>
void Controller<TLDRAM>::cmd_issue_autoprecharge(typename TLDRAM::Command& cmd,
                                                    const vector<int>& addr_vec) {
    //TLDRAM currently does not have autoprecharge commands
    return;
}

} /* namespace ramulator */
#endif

#include "Controller.h"
#include "DDR4.h"
#include "Processor.h"
using namespace ramulator;

namespace ramulator
{
template <typename T>
    void Controller<T>::tick(bool can_schedule)
    {
        clk++;
        req_queue_length_sum += readq.size() + writeq.size() + pending.size();
        read_req_queue_length_sum += readq.size() + pending.size();
        write_req_queue_length_sum += writeq.size();

        rolling_sum_queue_length += readq.size() + pending.size();

        if (dynamic_policy)
        {
            if (clk % 1000 == 0)
            {
                int avg_len = rolling_sum_queue_length/1000;
                //printf("%d\n",avg_len);
                if (avg_len > 30 && dynamicOn == false)
                {
                    dynamicOn = true;
                    proc->turnSectorDRAMOn();
                }
                else if (avg_len <= 30 && dynamicOn == true)
                {
                    dynamicOn = false;
                    proc->turnSectorDRAMOff();
                }
                rolling_sum_queue_length = 0;
            }
        }

        if(warmup_complete && !dpower_is_reset) {
            discard_DPowerWindow(); // discarding the last window results collected during warmup
            dpower_is_reset = true;
        }

        const uint32_t DPOWER_UPDATE_PERIOD = 50000000;
        if (clk % DPOWER_UPDATE_PERIOD == (DPOWER_UPDATE_PERIOD - 1)){
            if (warmup_complete)
                update_DPower();
            else
                discard_DPowerWindow();
        }



        /*** 1. Serve completed reads ***/
        if (pending.size()) {
            Request& req = pending[0];
            if (req.depart <= clk) {
                if (req.depart - req.arrive > 1) { // this request really accessed a row
                  read_latency_sum += req.depart - req.arrive;
                  channel->update_serving_requests(
                      req.addr_vec.data(), -1, clk);
                }

                if (sectoredDRAM && sector_size == 8)
                    assert(req.sector_bits[4] < 256);

                req.callback(req);
                pending.pop_front();

                /* Sectored DRAM (and SALP) */
                if(sectoredDRAM && sectoredDRAMSALP){
                    auto parallelRead = parallelReads.find(req.addr);
                    if( parallelRead != parallelReads.end()){
                        parallelRead->second.callback(parallelRead->second);
                        parallelReads.erase(req.addr);
                    }
                }
            }
        }

        /** Sectored DRAM **/
        // dequeue from FAW queue
        if (faw_queue.size())
        {
            if (clk - faw_queue.front().tick > 34 /*TODO: hardcoded, nFAW = 34 cycles in DDR4-3200 for x8 chips*/)
            {
                tFAW_budget += faw_queue.front().sectors;
                faw_queue.pop();
            }
        }

        /** Sectored DRAM **/

        /*** 2. Refresh scheduler ***/
        refresh->tick_ref();

        if (!can_schedule)
            return;

        /*** 3. Should we schedule writes? ***/
        if (!write_mode) {
            // yes -- write queue is almost full or read queue is empty
            if (writeq.size() > int(wr_high_watermark * writeq.max) || readq.size() == 0)
                write_mode = true;
        }
        else {
            // no -- write queue is almost empty and read queue is not empty
            if (writeq.size() < int(wr_low_watermark * writeq.max) && readq.size() != 0)
                write_mode = false;
        }

        /*** 4. Find the best command to schedule, if any ***/

        // First check the actq (which has higher priority) to see if there
        // are requests available to service in this cycle
        Queue* queue = &actq;
        typename T::Command cmd;
        auto req = scheduler->get_head(queue->q);

        bool is_valid_req = (req != queue->q.end());

        if(is_valid_req) {
            cmd = get_first_cmd(req);
            is_valid_req = is_ready(cmd, req->addr_vec);
        }

        if (!is_valid_req) {
            queue = !write_mode ? &readq : &writeq;

            if (otherq.size())
                queue = &otherq;  // "other" requests are rare, so we give them precedence over reads/writes

            req = scheduler->get_head(queue->q);

            is_valid_req = (req != queue->q.end());

            if(is_valid_req){
                cmd = get_first_cmd(req);
                is_valid_req = is_ready(cmd, req->addr_vec);

                // Fix the useless ACT bug: If the first RD/WR to an opened row is being delayed too much,
                // the PRE command from other requests could become ready which creates a useless activate
                // Solution: Make sure a row is kept open before at least 1 RD/WR is served.
                if (is_valid_req && channel->spec->is_closing(cmd))
                {
                    auto begin = req->addr_vec.begin();
                    auto end = begin + int(T::Level::Row);
                    std::vector<int> rowgroup(begin, end);

                    auto match = rowtable->table.find(rowgroup);
                    if(match == rowtable->table.end())
                        is_valid_req = true;
                    else
                    {
                        if (match->second.hits == 0)
                            is_valid_req = false;
                    }

                }
            }
        }

        if (!is_valid_req) {
            // we couldn't find a command to schedule -- let's try to be speculative
            auto cmd = T::Command::PRE;
            vector<int> victim = rowpolicy->get_victim(cmd);
            if (!victim.empty()){
                issue_cmd(cmd, victim, 0UL);
            }
            return;  // nothing more to be done this cycle
        }

        /* Check for requests that we can schedule in parallel (Sectored DRAM) */
        if(sectoredDRAM && sectoredDRAMSALP) {
            int acts = 0;
            auto parallel_reqs = scheduler->get_parallel_request(queue->q, req);
            if(!parallel_reqs.empty()) {
                ulong collapsed_sector_bits = req->sector_bits[4];
                for(auto parallel_req = parallel_reqs.begin();parallel_req!=parallel_reqs.end();parallel_req++){
                    // Found a request that we can execute in parallel
                    // remove it from the queue

                    if(debug)
                        std::cout << "Parallel request:" <<  (*parallel_req)->addr << std::endl;

                    if(req->type == Request::Type::READ) 
                        parallelReads.insert(std::pair<long int, Request>(req->addr,**parallel_req));
                    
                    queue->q.erase(*parallel_req);
                    collapsed_sector_bits = collapsed_sector_bits | (*parallel_req)->sector_bits[4];
                }
                acts += count_activated_sectors(collapsed_sector_bits);
            }
            else {
                acts += count_activated_sectors(req->sector_bits[4]);
            }

            //Check tFAW
            if(cmd == T::Command::ACT) {
                if((tFAW_budget - acts) <= 0)
                {
                    // we do not have enough budget, controller will remember this
                    faw_penalty_cycles++;
                    return;
                }
                // we can issue ACT (PRA)
                // reduce faw budget
                tFAW_budget -= acts;
                faw_queue.push({clk, acts});
            }
        }
        /* End SectoredDRAM with parallelization */

        /* SectoredDRAM on its own without parallelization */
        if (sectoredDRAM || partialActivationDRAM || fgDRAM || halfDRAM)
        {
            int acts = count_activated_sectors(req->sector_bits[4]);

            if (partialActivationDRAM)
                if (req->type == Request::Type::READ)
                    acts = 64/sector_size;

            if (fgDRAM)
                acts = 1; // always opens one sector

            if (halfDRAM)
                acts = 64/sector_size/2; // always opens half a row

            if (sectoredDRAM && burstChopDRAM)
                acts = 64/sector_size;

            //Check tFAW
            if(cmd == T::Command::ACT) {
                if((tFAW_budget - acts) < 0)
                {
                    // we do not have enough budget, controller will remember this
                    faw_penalty_cycles++;
                    return;
                }
                // we can issue ACT (PRA)
                // reduce faw budget
                tFAW_budget -= acts;
                faw_queue.push({clk, acts});
            }
        }
        else
        {
            int acts = 1;
            if(cmd == T::Command::ACT) {
                if((tFAW_budget - acts) < 0)
                {
                    // we do not have enough budget, controller will remember this
                    faw_penalty_cycles++;
                    return;
                }
                // we can issue ACT (PRA)
                // reduce faw budget
                tFAW_budget -= acts;
                faw_queue.push({clk, acts});
            }
        }
        /* End SectoredDRAM */

        if (req->is_first_command) {
            req->is_first_command = false;
            int coreid = req->coreid;
            if (req->type == Request::Type::READ || req->type == Request::Type::WRITE || req->type == Request::Type::PREFETCH) {
              channel->update_serving_requests(req->addr_vec.data(), 1, clk);
            }

            int tx = (channel->spec->prefetch_size * channel->spec->channel_width / 8);

            // These stay as sector_bits[3] because these requests
            // want to read only that many sectors
            if (sectoredDRAM)
                tx = sector_size * __builtin_popcountll(req->sector_bits[3]);

            if (burstChopDRAM)
            {
                if (__builtin_popcountll(req->sector_bits[3]) > 4)
                    tx = sector_size * 8;
                else
                    tx = sector_size * 4; // ASSUMING SECTOR SIZE IS 8 bytes
            }
            
            if (partialActivationDRAM && (req->type == Request::Type::WRITE))
                tx = sector_size * __builtin_popcountll(req->sector_bits[3]);


            if (req->type == Request::Type::READ || req->type == Request::Type::PREFETCH) {
                //printf("READ Transferring %d bytes, %f\n", tx, rolling_avg_tx);
                float temp_avg = rolling_avg_tx * samples_tx;
                samples_tx++;
                rolling_avg_tx = (temp_avg + tx)/samples_tx;

                if (is_row_hit(req)) {
                    ++read_row_hits[coreid];
                    ++row_hits;
                } else if (is_sector_miss(req)) {
                  ++read_sector_misses[coreid];
                  ++sector_misses;
                } else if (is_row_open(req)) {
                    ++read_row_conflicts[coreid];
                    ++row_conflicts;
                } else {
                    ++read_row_misses[coreid];
                    ++row_misses;
                }
              read_transaction_bytes += tx;
            } else if (req->type == Request::Type::WRITE) {

            //printf("WRITE Transferring %d bytes, %f\n", tx, rolling_avg_tx);
            float temp_avg = rolling_avg_tx * samples_tx;
            samples_tx++;
            rolling_avg_tx = (temp_avg + tx)/samples_tx;

              if (is_row_hit(req)) {
                  ++write_row_hits[coreid];
                  ++row_hits;
              } else if (is_sector_miss(req)) {
                  ++write_sector_misses[coreid];
                  ++sector_misses;
              } else if (is_row_open(req)) {
                  ++write_row_conflicts[coreid];
                  ++row_conflicts;
              } else {
                  ++write_row_misses[coreid];
                  ++row_misses;
              }
              write_transaction_bytes += tx;
            }
        }

        // issue command on behalf of request
        if (cmd == T::Command::ACT)
            issue_cmd(cmd, get_addr_vec(cmd, req), req->sector_bits[4]);
        else
            issue_cmd(cmd, get_addr_vec(cmd, req), req->sector_bits[3]);

        if (sectoredDRAM && sector_size == 8 && req->type != Request::Type::REFRESH)
            assert(req->sector_bits[4] < 256);

        // check whether this is the last command (which finishes the request)
        //if (cmd != channel->spec->translate[int(req->type)]){
        if (cmd != channel->spec->translate[int(req->type)]) {
            if(channel->spec->is_opening(cmd)) {
                // promote the request that caused issuing activation to actq
                actq.q.push_back(*req);
                queue->q.erase(req);
            }

            return;
        }

        // set a future completion time for read requests
        if (req->type == Request::Type::READ || req->type == Request::Type::PREFETCH) {
            req->depart = clk + channel->spec->read_latency;
            if (burstChopDRAM)
            {
                // Retrieve more sectors instead, because we read at least four of them
                if (req->sector_bits[3] & 0xF) // at least one of the first four bits are set, so set them all
                    req->sector_bits[3] |= 0xF;
                if (req->sector_bits[3] & 0xF0) // at least one of the last four bits are set, so set them all
                    req->sector_bits[3] |= 0xF0;
            }
            if (fgDRAM)
                req->depart = clk + channel->spec->read_latency * 64/sector_size;
            pending.push_back(*req);
        }

        if (req->type == Request::Type::WRITE) {
            channel->update_serving_requests(req->addr_vec.data(), -1, clk);
            // req->callback(*req);
        }

        // remove request from queue
        queue->q.erase(req);
    }

    template class Controller<DDR4>;

}