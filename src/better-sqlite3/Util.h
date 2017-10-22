//
// Created by slanska on 2017-10-21.
//

#ifndef FLEXILITE_UTIL_H
#define FLEXILITE_UTIL_H

#include <cstdint>

/*
 * Counterpart to better=sqlite4 RunResult interface
 */
class RunResult
{
public:
    int64_t changes;
    int64_t lastInsertROWID;
};

#endif //FLEXILITE_UTIL_H
