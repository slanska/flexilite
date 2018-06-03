---
--- Created by slanska.
--- DateTime: 2017-12-19 7:29 PM
---

-- Bit flags and related helper functions

local Constants = {
    MAX_NUMBER = 1.7976931348623157e+308,
    MIN_NUMBER = -1.7976931348623157e+308,
    MAX_INTEGER = 9007199254740992,
    MIN_INTEGER = -9007199254740992,

    MAX_BLOB_LENGTH = 1073741824,

    -- Specific value type, stored in .ref-values.ctlv and .objects.vtypes fields
    vtype = {
        default = 0, -- Use original SQLite type, i.e. NULL, FLOAT, INTEGER, TEXT, BLOB
        datetime = 1, -- (for FLOAT),
        timespan = 2, -- (for FLOAT),
        symbol = 3, -- (for INT)
        money = 4, --(for INT) - as integer value with fixed 4 decimal points (exact value for +-1844 trillions)
        json = 5, --(for TEXT)
        enum = 6, -- (for INT, TEXT etc.)
        reference = 7, -- value is object ID
    },

    -- CTLV flags
    --[[
    bits: 0-2 - specific value type (vtypes)
    bit 3: unique index
    bit 4: non-unique index
    bits: 5-7 - reference
    bit 8 - invalid value
    bit 9 - deleted
    bit 10 - no track changes
    ]]
    CTLV_FLAGS = {
        VTYPE_MASK = 7,
        UNIQUE = 0x0008,
        INDEX = 0x0010,
        REF_STD = 32, -- 1 << 5
        -- 4(5) - ref: A -> B. When A deleted, delete B
        DELETE_B_WHEN_A = 64, -- 2 << 5
        -- 6(7) - when B deleted, delete A
        DELETE_A_WHEN_B = 96, -- 3 << 5
        -- 8(9) - when A or B deleted, delete counterpart
        DELETE_COUNTERPART = 128, -- 4 << 5
        --10(11) - cannot delete A until this reference exists
        CANNOT_DELETE_A_UNTIL_B = 160, -- 5 << 5
        --12(13) - cannot delete B until this reference exists
        CANNOT_DELETE_B_UNTIL_A = 192, -- 6 << 5
        --14(15) - cannot delete A nor B until this reference exist
        CANNOT_DELETE_UNTIL_COUNTERPART = 224, -- 7 << 5
        INVALID_DATA = 0x0100,
        DELETED = 0x0200,
        NO_TRACK_CHANGES = 0x0400,
        FORMULA = 0x0800,
        INDEX_AND_REFS_MASK = 0x00F0,
        ALL_REFS_MASK = 0x00E0,
    },

    -- .objects.ctlo bit masks
    -- bits 0 - 15 - non unique indexes for A - P
    -- bits 16 - 31 - unique indexes for A - P
    -- bit 32 - deleted
    -- bit 33 - invalid data
    -- bit 34 - has accessRules in MetaData
    -- bit 35 - has colsMetaData in MetaData
    -- bit 36 - has formulas in MetaData
    -- bit 37 - WEAK object - and must be auto deleted after last reference to this object gets deleted.
    -- bit 38 - don't track changes
    -- ... ?
    CTLO_FLAGS = {
        UNIQUE_SHIFT = 0,
        INDEX_SHIFT = 16,
        -- skip first 32 bits
        DELETED = 0x100000000,
        INVALID_DATA = 0x200000000,
        HAS_ACCESS_RULES = 0x400000000,
        HAS_COL_META_DATA = 0x800000000,
        HAS_FORMULAS = 0x1000000000,
        WEAK_OBJECT = 0x2000000000, -- TODO reserved for future
        NO_TRACK_CHANGES = 0x4000000000, -- TODO reserved for future
    },

    -- Used for access rules
    OPERATION = {
        CREATE = 'C',
        READ = 'R',
        UPDATE = 'U',
        DELETE = 'D',
        EXECUTE = 'E',
        DENY = 'N',
        ALL = '*'
    },

    -- Bit flags for different types of property indexes
    INDEX_TYPES = {
        NON = 0,
        FTS = 0x0001,
        RNG = 0x0002,
        UNQ = 0x0004,
        STD = 0x0008,
        MUL = 0x0010,
        -- Full text index supported, but for search only (used by SymNameProperty and Enum text values)
        FTS_SEARCH = 0x0020,
    },

    DBOBJECT_SANDBOX_MODE = {
        FILTER = 'F',
        ORIGINAL = 'O',
        CURRENT = 'C',
        EXPRESSION = 'E',
    },

    -- Epsilon value for float equality comparison
    EPSILON = 1E-5,
    --EPSILON = 1E-12,

}

return Constants