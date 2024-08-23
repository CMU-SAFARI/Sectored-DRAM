#ifndef __SPATIAL_PREDICTOR
#define __SPATIAL_PREDICTOR

#include <unordered_map>
#include <vector>
#include "Config.h"
#include "Request.h"
#include "Statistics.h"

class SpatialPredictor
{

public:
    SpatialPredictor(const ramulator::Config& configs, const int id);
    ulong predict(ulong inst_addr, ulong load_addr);
    void update(ulong inst_addr, ulong load_addr, ulong pb_bv);

private:
    int coreid = 0;
    int sector_size = 0;
    bool m_enable = false;
    bool untrained_policy_no_prediction = true; // by default do not predict any sectors if untrained
    int pattern_table_size = 0;
    int log_pattern_table_size = 0;
    int m_log_blocksize = 6; // log cache block size
    int m_ways = 0;
    // How large of a window of evictions do we track
    // to determine accesses utilize all words
    int m_utilization_window = 0;
    std::vector<std::vector<ulong>> pattern_table;
    std::vector<std::vector<ulong>> tag_array;
    std::vector<ulong> way_meta;
    std::vector<int> rolling_average_utilization;
    float rolling_average = 0;
    int rolling_average_counter = 0;
    bool infinite_table = false;

    std::unordered_map<ulong, ulong> hashtable;

    //ramulator::ScalarStat untrained_prediction;
    //ramulator::ScalarStat trained_prediction;

    void update_rolling_average_util(ulong pb_bv);

    int find_index (ulong inst_addr, ulong load_addr);
    ulong find_tag (ulong inst_addr, ulong load_addr);

};

#endif