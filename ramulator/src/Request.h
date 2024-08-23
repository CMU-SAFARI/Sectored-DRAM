#ifndef __REQUEST_H
#define __REQUEST_H

#include <vector>
#include <functional>
#include <cassert>

using namespace std;
typedef unsigned long ulong;
typedef unsigned int uint;
namespace ramulator
{

class Request
{
public:
    bool is_first_command;
    long addr;
    bool cache_hit = false;
    int hit_level = 0;
    // long addr_row;
    vector<int> addr_vec;
    //ulong sector_bits;
    ulong sector_bits [5]; // one level for the original request (from processor) 3 levels for a 3-level hierarchy + 1 level for the memory controller
    ulong actual_access; // which sector does this request want to bring?
    long inst_addr;
    int size; // size of the access
    // specify which core this request sent from, for virtual address translation
    int coreid;

    enum class Type
    {
        READ,
        WRITE,
        REFRESH,
        POWERDOWN,
        SELFREFRESH,
        PREFETCH,
        EXTENSION,
        MAX
    } type;

    long arrive = -1;
    long depart = -1;
    function<void(Request&)> callback; // call back with more info

    Request(long addr, Type type, int coreid = 0)
        : is_first_command(true), addr(addr), coreid(coreid), type(type),
      callback([](Request& req){}) {}

    Request(long addr, Type type, function<void(Request&)> callback, int coreid = 0)
        : is_first_command(true), addr(addr), coreid(coreid), type(type), callback(callback) {}


    Request(vector<int>& addr_vec, Type type, function<void(Request&)> callback, int coreid = 0)
        : is_first_command(true), addr_vec(addr_vec), coreid(coreid), type(type), callback(callback) {}

    Request()
        : is_first_command(true), coreid(0) {}

    Request(const Request& req) : is_first_command(req.is_first_command), addr(req.addr), coreid(req.coreid), type(req.type), callback(req.callback) 
    {
        //assert(false && "Why was I called???");

        for (int i = 0; i < 5; i++)
            sector_bits[i] = req.sector_bits[i];
        arrive = req.arrive;
        depart = req.depart;

        actual_access = req.actual_access;
        inst_addr = req.inst_addr;
        size = req.size;
        hit_level = req.hit_level;
        cache_hit = req.cache_hit;

        // copy addr_vec
        addr_vec.resize(req.addr_vec.size());
        for (int i = 0; i < req.addr_vec.size(); i++)
            addr_vec[i] = req.addr_vec[i];
    }

};

} /*namespace ramulator*/

#endif /*__REQUEST_H*/

