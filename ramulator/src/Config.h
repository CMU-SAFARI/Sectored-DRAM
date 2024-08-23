#ifndef __CONFIG_H
#define __CONFIG_H

#include <string>
#include <fstream>
#include <vector>
#include <map>
#include <iostream>
#include <cassert>

namespace ramulator
{

class Config {

private:
    std::map<std::string, std::string> options;
    int channels;
    int ranks;
    int subarrays;
    int cpu_tick;
    int mem_tick;
    int core_num = 0;
    long expected_limit_insts = 0;
    long warmup_insts = 0;
    int sector_size = 0; // 0 is the default, no sectors
    int lookahead_size = 1; // 1 is the default, no lookahead
    int pattern_table_size = 8;
    int pattern_table_ways = 8;
    int utilization_window = 64;

    int stride_pref_mode = 0;
    int stride_pref_entries = 0;
    int stride_pref_single_stride_tresh = 0;
    int stride_pref_multi_stride_tresh = 0;
    int stride_pref_stride_start_dist = 0;
    int stride_pref_stride_degree = 0;
    int stride_pref_stride_dist = 0;

    std::string dpower_config_path;

public:
    Config() {}
    Config(const std::string& fname);
    void parse(const std::string& fname);
    std::string operator [] (const std::string& name) const {
      if (options.find(name) != options.end()) {
        return (options.find(name))->second;
      } else {
        return "";
      }
    }

    bool contains(const std::string& name) const {
      if (options.find(name) != options.end()) {
        return true;
      } else {
        return false;
      }
    }

    void add (const std::string& name, const std::string& value) {
      if (!contains(name)) {
        options.insert(make_pair(name, value));
      } else {
        printf("ramulator::Config::add options[%s] already set.\n", name.c_str());
      }
    }

    void set_core_num(int _core_num) {core_num = _core_num;}

    int get_channels() const {return channels;}
    int get_subarrays() const {return subarrays;}
    int get_ranks() const {return ranks;}
    int get_cpu_tick() const {return cpu_tick;}
    int get_mem_tick() const {return mem_tick;}
    int get_core_num() const {return core_num;}
    long get_expected_limit_insts() const {return expected_limit_insts;}
    long get_warmup_insts() const {return warmup_insts;}
    int get_sector_size() const {return sector_size;} 
    int get_lookahead_size() const {return lookahead_size;}
    int get_pattern_table_size() const {return pattern_table_size;}
    int get_pattern_table_ways() const {return pattern_table_ways;}
    int get_utilization_window_size() const {return utilization_window;}
    std::string get_dpower_config_path() const {return dpower_config_path;}


    int get_stride_pref_entries() const {return stride_pref_entries;} 
    int get_stride_pref_mode() const {return stride_pref_mode;}
    int get_stride_pref_single_stride_tresh() const {return stride_pref_single_stride_tresh;} 
    int get_stride_pref_multi_stride_tresh() const {return stride_pref_multi_stride_tresh;} 
    int get_stride_pref_stride_start_dist() const {return stride_pref_stride_start_dist;} 
    int get_stride_pref_stride_degree() const {return stride_pref_stride_degree;} 
    int get_stride_pref_stride_dist() const {return stride_pref_stride_dist;}

    bool is_sectoredDRAM() const {
      if (options.find("sectoredDRAM") != options.end()) {
        const std::string& option = (options.find("sectoredDRAM"))->second;
        return (option == "on");
      } else {
        return false;
      }           
    } 

    bool is_fgDRAM() const {
      if (options.find("fineGrainedDRAM") != options.end()) {
        const std::string& option = (options.find("fineGrainedDRAM"))->second;
        return (option == "on");
      } else {
        return false;
      }        
    }

    bool is_halfDRAM() const {
      if (options.find("halfDRAM") != options.end()) {
        const std::string& option = (options.find("halfDRAM"))->second;
        return (option == "on");
      } else {
        return false;
      }            
    }

    bool is_partialActivationDRAM() const {
      if (options.find("partialActivationDRAM") != options.end()) {
        const std::string& option = (options.find("partialActivationDRAM"))->second;
        return (option == "on");
      } else {
        return false;
      }      
    }

    bool is_DGMS() const {
      if (options.find("DGMS") != options.end()) {
        const std::string& option = (options.find("DGMS"))->second;
        return (option == "on");
      } else {
        return false;
      }      
    }

    bool is_lookahead_predictor_enabled() const {
      if (options.find("lookahead_predictor") != options.end()) {
        const std::string& lap_option = (options.find("lookahead_predictor"))->second;
        return (lap_option == "on");
      } else {
        return false;
      }      
    }

    bool is_slow_cache() const {
      if (options.find("slow_cache") != options.end()) {
        const std::string& lap_option = (options.find("slow_cache"))->second;
        return (lap_option == "on");
      } else {
        return false;
      }      
    }

    bool is_burstChopDRAM() const {
      if (options.find("burstChopDRAM") != options.end()) {
        const std::string& lap_option = (options.find("burstChopDRAM"))->second;
        return (lap_option == "on");
      } else {
        return false;
      }      
    }

    bool is_spatial_predictor_enabled() const {
      if (options.find("spatial_predictor") != options.end()) {
        const std::string& sp_option = (options.find("spatial_predictor"))->second;
        return (sp_option == "on");
      } else {
        return false;
      }      
    }

    bool is_untrained_policy_no_prediction() const {
      if (options.find("untrained_policy_no_prediction") != options.end()) {
        const std::string& sp_option = (options.find("untrained_policy_no_prediction"))->second;
        return (sp_option == "yes");
      } else {
        return false;
      }      
    }

    bool is_parallelization_enabled() const {
      if (options.find("parallelization") != options.end()) {
        const std::string& par_option = (options.find("parallelization"))->second;
        return (par_option == "on");
      } else {
        return false;
      }      
    }

    bool has_l3_cache() const {
      if (options.find("cache") != options.end()) {
        const std::string& cache_option = (options.find("cache"))->second;
        return (cache_option == "all") || (cache_option == "L3");
      } else {
        return false;
      }
    }
    bool has_core_caches() const {
      if (options.find("cache") != options.end()) {
        const std::string& cache_option = (options.find("cache"))->second;
        return (cache_option == "all" || cache_option == "L1L2");
      } else {
        return false;
      }
    }
    bool is_early_exit() const {
      // the default value is true
      if (options.find("early_exit") != options.end()) {
        if ((options.find("early_exit"))->second == "off") {
          return false;
        }
        return true;
      }
      return true;
    }
    bool calc_weighted_speedup() const {
      return (expected_limit_insts != 0);
    }
    bool record_cmd_trace() const {
      // the default value is false
      if (options.find("record_cmd_trace") != options.end()) {
        if ((options.find("record_cmd_trace"))->second == "on") {
          return true;
        }
        return false;
      }
      return false;
    }
    bool print_cmd_trace() const {
      // the default value is false
      if (options.find("print_cmd_trace") != options.end()) {
        if ((options.find("print_cmd_trace"))->second == "on") {
          return true;
        }
        return false;
      }
      return false;
    }
    bool is_prefetcher() const {
      // the default value is false
      if (options.find("prefetcher") != options.end()) {
        if ((options.find("prefetcher"))->second == "on") {
          return true;
        }
        return false;
      }
      return false;
    }

    bool is_dynamic_policy() const {
      // the default value is false
      if (options.find("dynamic_policy") != options.end()) {
        if ((options.find("dynamic_policy"))->second == "on") {
          return true;
        }
        return false;
      }
      return false;
    }
};


} /* namespace ramulator */

#endif /* _CONFIG_H */

