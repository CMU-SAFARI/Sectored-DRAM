#include <algorithm>
#include <cassert>
#include <stdio.h>

#include "CacheSet.h"

CacheSet::CacheSet(const int nWays, const PolicyType replacementPolicy) :
    replacementPolicy(replacementPolicy),
    nWays(nWays),
    sectorValids(nWays, 0UL), // all sectors are invalid
    instAddresses(nWays, 0UL),
    usedSectors(nWays, 0UL), // all sectors are unused
    dirtySectors(nWays, 0UL),
    tags(nWays, 0UL), // all tags are "0"
    validVec(0UL), // nothing is valid
    busyVec(0UL), // nothing is busy
    dirtyVec(0UL), // nothing is dirty
    mruVec(0UL) // nothing is most recently used
    {}

bool CacheSet::isValid(const long tag)
{
    int i = findWayIdx(tag);
    if (i == -1)
        return false;
    return bvMatchIdx(validVec, i);
}

bool CacheSet::isBusy(const long tag)
{
    int i = findWayIdx(tag);
    if (i == -1)
        return false;
    return bvMatchIdx(busyVec, i);
}

bool CacheSet::isDirty(const long tag)
{
    int i = findWayIdx(tag);
    if (i == -1)
        return false;
    return bvMatchIdx(dirtyVec, i);
}

long CacheSet::findVictim()
{
    if (replacementPolicy == PolicyType::MRU)
    {
        ulong plruBits = (~mruVec) & ((1UL << nWays) - 1);

        assert(plruBits && "MRU bits should never be all one");

        int i = 0;
        while (i < nWays)
        {
            if (plruBits & 0x1)
                return tags[i];
            plruBits >>= 1;
            i++;
        }
        return -1;
    }
    else
        return -1;
}

bool CacheSet::canEvict(long tag)
{
    int i = findWayIdx(tag);

    // if tag does not exist, it should be OK to "evict" this block
    // before modifying cache state, cache.cpp checks if the block is
    // valid anyways
    if (i < 0)
        return true;

    // If a block is not busy, it should be evictable
    return !bvMatchIdx(busyVec, i);
}

bool CacheSet::evict(const long tag)
{
    int i = findWayIdx(tag);

    if (i == -1)
        return false;

    bvUnsetIdx(validVec, i);

    // assert(usedSectors[i] > 0 && "Did not use any sectors???");
    // printf("sectorValids:0x%lx usedSectors:0x%lx\n", sectorValids[i], usedSectors[i]);
    if (((~sectorValids[i]) & usedSectors[i]))
        printf("SectorValids: 0x%lx usedSectors: 0x%lx\n", sectorValids[i], usedSectors[i]);
    assert(!((~sectorValids[i]) & usedSectors[i]) && "More sectors used than brought at the time of eviction");

    sectorValids[i] = 0UL;
    usedSectors[i] = 0UL;
    instAddresses[i] = 0LL;
    dirtySectors[i] = 0UL;

    bool isDirty = bvMatchIdx(dirtyVec, i);
    bvUnsetIdx(dirtyVec, i);
    bvUnsetIdx(mruVec, i);

    assert(bvMatchIdx(busyVec, i) == 0 && "Evicting a busy cache block");

    return isDirty;
}

// Update replacement metadata and actually used sectors
void CacheSet::access(const long tag, const ulong sectorBits, const bool isWrite)
{
    int i = findWayIdx(tag);
    assert(i >= 0 && "Accessing an invalid cache block");

    // TODO: is this fixed after a lot of modifications?
    assert(!((~sectorValids[i]) & sectorBits) && "Accessing an unexisting sector");
    usedSectors[i] |= sectorBits;

    if (isWrite)
    {
        dirtySectors[i] |= sectorBits;
        //printf("Someone made %d of my sectors dirty\n", __builtin_popcountll(sectorBits));
    }

    if (~usedSectors[i] & dirtySectors[i])
    {
        printf("NewSectors:%lx OldSectors:%lx %lx %lx\n", sectorBits, sectorValids[i], usedSectors[i], dirtySectors[i]);
    }

    assert (!(~usedSectors[i] & dirtySectors[i]) && "Dirty sectors only allowed if they are used");

    if (replacementPolicy == PolicyType::MRU)
    {
        bvSetIdx(mruVec, i);

        // All MRU bits are set, we need to zero others
        // TODO: check if bit arithmetic is sound
        if (((~mruVec) & ((1UL << nWays) - 1)) == 0)
        {
            mruVec = 0UL;
            bvSetIdx(mruVec, i);
        }
    }
}

void CacheSet::insert(const long oldTag, const long newTag, const long instAddr, const ulong sectorBits)
{
    int i = findWayIdx(oldTag);
    tags[i] = newTag;

    sectorValids[i] = sectorBits;
    usedSectors[i] = 0UL;
    dirtySectors[i] = 0UL;
    instAddresses[i] = instAddr;

    // Also update replacement state

    bvSetIdx(mruVec, i);

    // All MRU bits are set, we need to zero others
    // TODO: check if bit arithmetic is sound
    if (((~mruVec) & ((1UL << nWays) - 1)) == 0)
    {
        mruVec = 0UL;
        bvSetIdx(mruVec, i);
    }

}

void CacheSet::validate(const long tag)
{
    int i = findWayIdx(tag);
    bvSetIdx(validVec, i);
}

void CacheSet::invalidate(const long tag)
{
    int i = findWayIdx(tag);
    assert(!isBusy(tag) && "Trying to invalidate block while its busy");
    bvUnsetIdx(validVec, i);

    sectorValids[i] = 0UL;
    usedSectors[i] = 0UL;
    dirtySectors[i] = 0UL;
}

void CacheSet::makeBusy(const long tag)
{
    int i = findWayIdx(tag);
    bvSetIdx(busyVec, i);
}

void CacheSet::makeIdle(const long tag)
{
    int i = findWayIdx(tag);
    bvUnsetIdx(busyVec, i);
}


void CacheSet::makeDirty(const long tag)
{
    int i = findWayIdx(tag);
    bvSetIdx(dirtyVec, i);
}

bool CacheSet::areSectorsValid(const long tag, const ulong sectorBits)
{
    int i = findWayIdx(tag);
    assert(i >= 0 && "Are sectors valid called on invalid tag");
    //printf("Are Sectors Valid? My sectors: 0x%lx, Asked from me: 0x%lx\n", sectorValids[i], sectorBits);

    if ((~sectorValids[i]) & sectorBits)
        return false;
    else
        return true;
}

ulong CacheSet::findMissingSectors(const long tag, const ulong sectorBits)
{
    int i = findWayIdx(tag);
    assert(i != -1 && "findMissingSectors called on non-existing tag");
    return (~sectorValids[i]) & sectorBits;
}

ulong CacheSet::getSectorBits(const long tag)
{
    int i = findWayIdx(tag);
    if (i == -1)
        return 0UL;
    return sectorValids[i];
}

void CacheSet::insertSectors(const long tag, const ulong sectorBits)
{
    int i = findWayIdx(tag);
    sectorValids[i] |= sectorBits;
}

ulong CacheSet::getUsedSectors(const long tag)
{
    int i = findWayIdx(tag);
    if (i == -1)
        return 0UL;
    return usedSectors[i];
}

ulong CacheSet::getDirtySectors(const long tag)
{
    int i = findWayIdx(tag);
    if (i == -1)
        return 0UL;
    return dirtySectors[i];
}

long CacheSet::getInstAddr(const long tag)
{
    int i = findWayIdx(tag);
    return instAddresses[i];
}


// Helper functions

int CacheSet::findWayIdx(const long tag)
{
    for (int i = 0 ; i < nWays ; i++)
        if (tags[i] == tag)
            return i;

    return -1;
}

bool CacheSet::bvMatchIdx(const ulong bv, const int idx)
{
    return bv & (1UL << idx);
}

void CacheSet::bvSetIdx(ulong& bv, const int idx)
{
    bv |= (1UL << idx);
}

void CacheSet::bvUnsetIdx(ulong& bv, const int idx)
{
    bv &= ~(1UL << idx);
}

bool CacheSet::invalidBlockExists()
{
    return (~validVec) & ((1UL << nWays) - 1);
}

ulong CacheSet::getValidVec()
{
    return validVec;
}

ulong CacheSet::getBusyVec()
{
    return busyVec;
}

ulong CacheSet::getDirtyVec()
{
    return dirtyVec;
}

std::vector<ulong> CacheSet::getTags()
{
    return tags;
}