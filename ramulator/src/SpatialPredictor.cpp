#include "SpatialPredictor.h"

#include <iostream>
#include <cmath>

// pb_bv = sector bits, this code is adapted
// from an older generation of the simulation infrastructure

SpatialPredictor::SpatialPredictor(const ramulator::Config& configs, const int id)
{
    sector_size = configs.get_sector_size();
    m_enable = configs.is_spatial_predictor_enabled();
    pattern_table_size = configs.get_pattern_table_size();
    m_ways = configs.get_pattern_table_ways();
    m_utilization_window = configs.get_utilization_window_size();
    untrained_policy_no_prediction = configs.is_untrained_policy_no_prediction();
    infinite_table = false;
    coreid = id;

    if (m_enable)
        std::cout << "Spatial predictor is enabled" << std::endl;

    if (m_enable && pattern_table_size == 0){
        std::cout << "Infinite pattern table" << std::endl;
        assert(!m_utilization_window && "not compatible with infinite table");
        infinite_table = true;
    }
    
    rolling_average_utilization = std::vector<int> (m_utilization_window, 0); // How many 
    rolling_average_counter = 0;
    pattern_table.resize(m_ways);
    tag_array.resize(m_ways);
    // currently stores the most recently used way
    way_meta = std::vector<ulong> (pattern_table_size, 0);
    for (int i = 0 ; i < m_ways ; i++)
    {
        pattern_table[i] = std::vector<ulong> (pattern_table_size, 0);
        tag_array[i] = std::vector<ulong> (pattern_table_size, 0);
    }

    log_pattern_table_size = (int) std::log2(pattern_table_size);

    // TODO: fix to use coreids correctly
    /*
    untrained_prediction.name(string("spatial_predictor_") + std::to_string(coreid) + string("_untrained_prediction"))
                    .desc("times the predictor made a prediction without being trained")
                    .precision(0)
                    ;

    trained_prediction.name(string("spatial_predictor_") + std::to_string(coreid) + string("_trained_prediction"))
                    .desc("times the predictor made a prediction while being trained")
                    .precision(0)
                    ;
    */
}

int SpatialPredictor::find_index(ulong inst_addr, ulong load_addr)
{
    // Mix IA LA
    //UInt64 index = (((inst_addr >> 12)^inst_addr) ^ (load_addr >> 6)) & (pattern_table_size - 1);
    // IA + alignment: DGMS
    ulong index = ((((inst_addr >> 12) ^ inst_addr) ^ ((load_addr >> 3) & 0x7))) & (pattern_table_size - 1);
    return index;
}

ulong SpatialPredictor::find_tag(ulong inst_addr, ulong load_addr)
{
    if (infinite_table)
    {
        ulong key = inst_addr ^ load_addr; // Mix up two things
        return key;
    }
    else
    {
        // DGMS tags: "track a total amount of 512 instructions"
        ulong tag = (((((inst_addr >> 12) ^ inst_addr) + ((load_addr >> 3) & 0x7))) >> log_pattern_table_size);
        //ulong tag = (((((inst_addr >> 12) ^ inst_addr) + ((load_addr >> 3) & 0x7))) >> log_pattern_table_size) & 0x7f;
        return tag;
    }
}

ulong SpatialPredictor::predict(ulong inst_addr, ulong load_addr)
{
    if (!m_enable) return 0;

    if (infinite_table)
    {
        ulong key = find_tag(inst_addr, load_addr);
        if (hashtable.find(key) != hashtable.end())
        {
            //trained_prediction++;
            return hashtable[key];
        }
        else 
        {
            //untrained_prediction++;
            return untrained_policy_no_prediction ? 0 : (1 << (64/sector_size)) - 1;
        }
    }

    ulong index = find_index(inst_addr, load_addr);
    ulong tag = find_tag(inst_addr, load_addr);

    bool found = false;
    int found_way = 0;
    for (int i = 0 ; i < m_ways ; i++)
    {
        if (tag_array[i][index] == tag)
        {
            found = true;
            found_way = i;
            break;
        }
    } 

    if (found)
    {
        way_meta[index] = found_way;
        //trained_prediction++;
        //if (m_utilization_window && rolling_average > 3.75)
            //return (1 << (64/sector_size)) - 1;
        return pattern_table[found_way][index];
    }

    //untrained_prediction++;
    if (m_utilization_window && rolling_average >= 4)
        return (1 << (64/sector_size)) - 1;

    return untrained_policy_no_prediction ? 0 : (1 << (64/sector_size)) - 1;
}

void SpatialPredictor::update(ulong inst_addr, ulong load_addr, ulong pb_bv)
{
    if (!m_enable) return;

    if (infinite_table)
    {
        ulong key = find_tag(inst_addr, load_addr);
        hashtable[key] = pb_bv;
        return;
    }

    ulong index = find_index(inst_addr, load_addr);
    ulong tag = find_tag(inst_addr, load_addr);

    if (m_utilization_window)
        update_rolling_average_util(pb_bv);

    int replacement_way = 0;
    if (m_ways > 1)
        replacement_way = (way_meta[index] + (rand()%(m_ways-1))) % m_ways;

    tag_array[replacement_way][index] = tag;
    pattern_table[replacement_way][index] = pb_bv;    
}

void SpatialPredictor::update_rolling_average_util(ulong pb_bv)
{
    rolling_average -= ((float)rolling_average_utilization[rolling_average_counter])/m_utilization_window;
    rolling_average += ((float)__builtin_popcountll(pb_bv))/m_utilization_window;

    rolling_average_utilization[rolling_average_counter] = __builtin_popcountll(pb_bv);

    rolling_average_counter = (rolling_average_counter + 1) % m_utilization_window;

    if (rolling_average > 8) rolling_average = 8;
    if (rolling_average < 0) rolling_average = 0;

    assert(rolling_average <= 8);
    assert(rolling_average >= 0);
}