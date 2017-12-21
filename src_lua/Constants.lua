---
--- Created by slanska.
--- DateTime: 2017-12-19 7:29 PM
---

-- Bit flags and related helper functions

local Constants = {
    -- Candidates for common.lua
    MAX_NUMBER = 1.7976931348623157e+308,
    -- Smallest number = 2.2250738585072014e-308,
    MIN_NUMBER = -MAX_NUMBER,
    MAX_INTEGER = 9007199254740992,
    MIN_INTEGER = -MAX_INTEGER,

    MAX_BLOB_LENGTH = 1073741824,

    -- CTLV flags
    CTLV_FLAGS = {
        INDEX = 1,
        REF_STD = 3,
        -- 4(5) - ref: A -> B. When A deleted, delete B
        DELETE_B_WHEN_A = 5,
        -- 6(7) - when B deleted, delete A
        DELETE_A_WHEN_B = 7,
        -- 8(9) - when A or B deleted, delete counterpart
        DELETE_COUNTERPART = 9,
        --10(11) - cannot delete A until this reference exists
        CANNOT_DELETE_A_UNTIL_B = 11,
        --12(13) - cannot delete B until this reference exists
        CANNOT_DELETE_B_UNTIL_A = 13,
        --14(15) - cannot delete A nor B until this reference exist
        CANNOT_DELETE_UNTIL_COUNTERPART = 15,
        NAME_ID = 16,
        FTX_INDEX = 32,
        NO_TRACK_CHANGES = 64,
        UNIQUE = 128,
        DATE = 256,
        TIMESPAN = 512,
    },

    -- Specific value type, stored in .ref-values.ctlv and .objects.vtypes fields
    vtype = {
        default = 0, -- Use SQLite type, i.e. NULL, FLOAT, INTEGER, TEXT, BLOB
        datetime = 1, -- (for FLOAT),
        timespan = 2, -- (for FLOAT),
        symbol = 3, -- (for INT)
        money = 4, --(for INT) - as integer value with fixed 4 decimal points (exact value for +-1844 trillions)
        json = 5, --(for TEXT)
        enum = 6, -- (for INT, TEXT etc.)
        reference = 7, -- (used only in .ref-values.ctlv, not applicable for .objects.vtypes])
    },

    -- Used for access rules
    AccessMode = {
        HIDDEN = 0x01,
        READ_ONLY = 0x02,
        UPDATABLE = 0x04,
        CAN_ADD = 0x08,
        CAN_DELETE = 0x10
    },

    -- Used for access rules
    ItemType = {
        Class = 'C',
        Property = 'P',
        Object = 'O'
    },
}

return Constants