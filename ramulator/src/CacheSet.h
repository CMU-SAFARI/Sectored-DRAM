#ifndef CACHE_SET_HPP
#define CACHE_SET_HPP

#include <vector>
// to include typedef ulong? UGLY
#include "Request.h"

class CacheSet
{
public:

    enum class PolicyType
    {
        MRU
    };

    CacheSet(const int nWays, const PolicyType replacementPolicy);

    bool isValid(const long tag);
    bool isBusy(const long tag);
    bool isDirty(const long tag);

    // To find out if eviction is possible
    // and if so, which tag to evict
    long findVictim();
    bool canEvict(const long tag);

    /**
     * Evict the cache block
     * @return true if dirty
     */
    bool evict(const long tag);

    // To manipulate replacement state
    // this should be called when
    // an action would ideally result in
    // fetching useful data from the cache array
    // E.g., hit in cache, sector miss in cache
    void access(const long tag, const ulong sectorBits, const bool isWrite);

    // To manipulate valid state
    void insert(const long oldTag, const long newTag, const long instAddr, const ulong sectorBits = 0);
    void validate(const long tag);
    void invalidate(const long tag);

    void makeDirty(const long tag);


    // To manipulate busy state
    // Busy: e.g., an MSHR is referencing this block
    //      to potentially bring in missing sector bits
    void makeBusy(const long tag);
    void makeIdle(const long tag);

    // Sector Cache extensions
    bool areSectorsValid(const long tag, const ulong sectorBits);
    ulong findMissingSectors(const long tag, const ulong sectorBits);
    ulong getSectorBits(const long tag);
    void insertSectors(const long tag, const ulong sectorBits);
    ulong getUsedSectors(const long tag); 
    ulong getDirtySectors(const long tag); 
    long getInstAddr(const long tag);

    ulong getValidVec();
    ulong getBusyVec();
    ulong getDirtyVec();
    std::vector<ulong> getTags();

private:

    PolicyType replacementPolicy;
    ulong nWays;

    // One-hot encoded values
    ulong validVec;
    ulong busyVec;
    ulong dirtyVec;

    // One-hot encoded metadata bits for MRU replacement policy
    ulong mruVec;

    // Sector Cache extensions
    // One-hot encoded values for every cache line (one in each way)  
    std::vector<ulong> sectorValids;
    std::vector<ulong> usedSectors;
    std::vector<ulong> dirtySectors;
    std::vector<long> instAddresses;
    // End Sector Cache extensions

    // Other cache metadata
    std::vector<ulong> tags;

    /**
     * Find if a tag is in the tags vector
     * @return the index of the tag if it exists, -1 otherwise
     */
    int findWayIdx(const long tag);

    /**
     * Find if an index is set in the bitvector
     */
    inline bool bvMatchIdx(const ulong bv, const int idx);

    inline void bvSetIdx(ulong& bv, const int idx);

    inline void bvUnsetIdx(ulong& bv, const int idx);

    bool invalidBlockExists();
};

#endif