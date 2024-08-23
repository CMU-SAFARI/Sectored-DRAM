#include "Config.h"

using namespace std;
using namespace ramulator;

Config::Config(const std::string& fname) {
  parse(fname);
}

void Config::parse(const string& fname)
{
    ifstream file(fname);
    assert(file.good() && "Bad config file");
    string line;
    while (getline(file, line)) {
        char delim[] = " \t=";
        vector<string> tokens;

        while (true) {
            size_t start = line.find_first_not_of(delim);
            if (start == string::npos) 
                break;

            size_t end = line.find_first_of(delim, start);
            if (end == string::npos) {
                tokens.push_back(line.substr(start));
                break;
            }

            tokens.push_back(line.substr(start, end - start));
            line = line.substr(end);
        }

        // empty line
        if (!tokens.size())
            continue;

        // comment line
        if (tokens[0][0] == '#')
            continue;

        // parameter line
        assert(tokens.size() == 2 && "Only allow two tokens in one line");

        options[tokens[0]] = tokens[1];

        if (tokens[0] == "channels") {
          channels = atoi(tokens[1].c_str());
        } else if (tokens[0] == "ranks") {
          ranks = atoi(tokens[1].c_str());
        } else if (tokens[0] == "subarrays") {
          subarrays = atoi(tokens[1].c_str());
        } else if (tokens[0] == "cpu_tick") {
          cpu_tick = atoi(tokens[1].c_str());
        } else if (tokens[0] == "mem_tick") {
          mem_tick = atoi(tokens[1].c_str());
        } else if (tokens[0] == "expected_limit_insts") {
          expected_limit_insts = atoi(tokens[1].c_str());
        } else if (tokens[0] == "warmup_insts") {
          warmup_insts = atoi(tokens[1].c_str());
        } else if (tokens[0] == "sector_size") {
          sector_size = atoi(tokens[1].c_str());
        } else if (tokens[0] == "lookahead_size") {
          lookahead_size = atoi(tokens[1].c_str());
        } else if (tokens[0] == "pattern_table_size") {
          pattern_table_size = atoi(tokens[1].c_str());
        } else if (tokens[0] == "pattern_table_ways") {
          pattern_table_ways = atoi(tokens[1].c_str());
        } else if (tokens[0] == "utilization_window") {
          utilization_window = atoi(tokens[1].c_str());
        } else if (tokens[0] == "dpower_config_path") {
          dpower_config_path = tokens[1];
        } else if (tokens[0] == "stride_pref_mode") {
          stride_pref_mode = atoi(tokens[1].c_str());
        } else if (tokens[0] == "stride_pref_entries") {
          stride_pref_entries = atoi(tokens[1].c_str());
        } else if (tokens[0] == "stride_pref_single_stride_tresh") {
          stride_pref_single_stride_tresh = atoi(tokens[1].c_str());
        } else if (tokens[0] == "stride_pref_multi_stride_tresh") {
          stride_pref_multi_stride_tresh = atoi(tokens[1].c_str());
        } else if (tokens[0] == "stride_pref_stride_start_dist") {
          stride_pref_stride_start_dist = atoi(tokens[1].c_str());
        } else if (tokens[0] == "stride_pref_stride_degree") {
          stride_pref_stride_degree = atoi(tokens[1].c_str());
        } else if (tokens[0] == "stride_pref_stride_dist") {
          stride_pref_stride_dist = atoi(tokens[1].c_str());
        }
        
    }
    file.close();
}


