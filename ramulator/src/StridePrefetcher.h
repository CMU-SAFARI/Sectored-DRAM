#ifndef __STRIDE_PREFETCHER
#define __STRIDE_PREFETCHER

// A Stride Prefetcher implementation based on "Effective Stream-Based and
// Execution-Based Data Prefetching", ICS'04
//
// Adapter from Scarab's "pref_stride"


#define PREF_STRIDE_REGION_BITS 16 // TODO: make configurable??? 
#define STRIDE_REGION(x) ( x >> (PREF_STRIDE_REGION_BITS) )

#include <functional>
#include "Request.h"

#ifdef ATB_HEADERS
#include "Types.h"
#endif

namespace ramulator
{
    class StridePrefetcher {
        protected:
            struct StrideRegionTableEntry {
                long tag;
                bool valid;
                uint last_access;
            };

            struct StrideIndexTableEntry {
                bool trained;
                bool train_count_mode;

                uint num_states;
                uint curr_state;
                long last_index;

                int stride[2];
                int s_cnt[2];
                int strans[2]; //== stride12, stride21

                int recnt;
                int count;

                int pref_count;
                uint pref_curr_state;
                long pref_last_index;

                uint pref_sent;
            };

            uint num_entries;
            StrideRegionTableEntry* region_table;
            StrideIndexTableEntry* index_table;
            function<bool(Request)> send;
            function<void(Request&)> callback;
            function<void(Request&)> proc_callback;

        private:
            const int CACHE_LINE_SIZE_BITS = 6; // TODO: cache line size is hardcoded in ramulator
                                                // to 64 bytes. Change this when making 
                                                // cache line size configurable

            bool issue_pref_req(long line_index, ulong sector_bits);

        public:

            // config. params
            enum class StridePrefMode {
                SINGLE_STRIDE,
                MAX
            } mode;

            int single_stride_threshold;
            int multi_stride_threshold;
            int stride_start_dist;
            int stride_degree;
            int stride_dist;
            // END - config params

            StridePrefetcher(uint num_stride_table_entries, StridePrefMode _mode, 
                    int _single_stride_threshold, int _multi_stride_threshold, 
                    int _stride_start_dist, int _stride_degree, int _stride_dist,
                    function<bool(Request)> _send, function<void(Request&)> _callback,
                    function<void(Request&)> _proc_callback);
            ~StridePrefetcher();

            void train(long line_addr, bool ul1_hit, long cur_clk, ulong sector_bits);
            void miss(long line_addr, long cur_clk, ulong sector_bits);
            void hit(long line_addr, long cur_clk, ulong sector_bits);

            void create_new_entry(int idx, long line_addr, long region_tag, long cur_clk);

    };

} // namespace ramulator


#endif // __STRIDE_PREFETCHER
