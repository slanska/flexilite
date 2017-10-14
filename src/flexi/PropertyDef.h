//
// Created by slanska on 2017-10-11.
//

#ifndef FLEXILITE_PROPERTYDEF_H
#define FLEXILITE_PROPERTYDEF_H

#include <memory>
#include <map>
#include <vector>
#include "../project_defs.h"
#include "SymbolRef.h"

// Forward declarations
class DBContext;

class EnumDef
{
};

class PropertyDef
{
public:
    std::shared_ptr<DBContext> context;
    sqlite3_int64 lClassID;
    sqlite3_int64 lPropID;
    std::string zType;
    SymbolRef name;
    short int type;
    short int xRole;
    char bIndexed;
    char bUnique;
    char bFullTextIndex;
    bool bNoTrackChanges;

    /*
 * If true, marks this property as the one that potentially has invalid existing data and
 * a candidate to run validation process. Flag is cleared after validation scan is done and no
 * invalid data was found.
 * Invalid data = does not pass property rules (type, maxLength, regex etc.)
 */
    bool bValidate;

    /*
     * Existing property data need to be validated
     */
    bool bValidateData;

    /*
     * Index type
     */
    std::string zIndex;
    std::string zSubType;

    /*
     * For properties being altered/renamed - will have new property name
     */
    std::string zRenameTo;

    char *regex;
    struct ReCompiled *pRegexCompiled;

    sqlite3_value *defaultValue;

    std::string zEnumDef;
    std::shared_ptr<EnumDef> pEnumDef;

    std::string zRefDef;
    ClassRef pRefDef;

    int maxLength;
    int minOccurences;

    int maxOccurences;
    int xCtlv;

    int xCtlvPlan;

    /*
 * 1-10: column is mapped to .range_data columns (1 = A0, 2 = A1, 3 = B0 and so on)
 * 0: not mapped
 */
    unsigned char cRangeColumn;

    /*
     * if not 0x00, mapped to a fixed column in [.objects] table (A-P)
     */
    unsigned char cColMapped;

    /*
     * 0 - no range column
     * 1 - low range bound
     * 2 - high range bound
     */
    unsigned char cRngBound;

    CHANGE_STATUS eChangeStatus;
};


#endif //FLEXILITE_PROPERTYDEF_H
