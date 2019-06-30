--[[
Created by slanska on 2019-06-30.
]]

local ffi = require 'ffi'
local normalizeSqlName = require('Util').normalizeSqlName
local List = require 'pl.List'
local Constants = require 'Constants'
local ClassDef = require 'ClassDef'

--TODO move cdef declarations to separate module

-- Register SQLite types specific for virtual table API
ffi.cdef [[
typedef long long int sqlite_int64;

typedef unsigned long long int sqlite_uint64;

/*
** CAPI3REF: Virtual Table Indexing Information
** KEYWORDS: sqlite3_index_info
**
** The sqlite3_index_info structure and its substructures is used as part
** of the [virtual table] interface to
** pass information into and receive the reply from the [xBestIndex]
** method of a [virtual table module].  The fields under **Inputs** are the
** inputs to xBestIndex and are read-only.  xBestIndex inserts its
** results into the **Outputs** fields.
**
** ^(The aConstraint[] array records WHERE clause constraints of the form:
**
** <blockquote>column OP expr</blockquote>
**
** where OP is =, &lt;, &lt;=, &gt;, or &gt;=.)^  ^(The particular operator is
** stored in aConstraint[].op using one of the
** [SQLITE_INDEX_CONSTRAINT_EQ | SQLITE_INDEX_CONSTRAINT_ values].)^
** ^(The index of the column is stored in
** aConstraint[].iColumn.)^  ^(aConstraint[].usable is TRUE if the
** expr on the right-hand side can be evaluated (and thus the constraint
** is usable) and false if it cannot.)^
**
** ^The optimizer automatically inverts terms of the form "expr OP column"
** and makes other simplifications to the WHERE clause in an attempt to
** get as many WHERE clause terms into the form shown above as possible.
** ^The aConstraint[] array only reports WHERE clause terms that are
** relevant to the particular virtual table being queried.
**
** ^Information about the ORDER BY clause is stored in aOrderBy[].
** ^Each term of aOrderBy records a column of the ORDER BY clause.
**
** The colUsed field indicates which columns of the virtual table may be
** required by the current scan. Virtual table columns are numbered from
** zero in the order in which they appear within the CREATE TABLE statement
** passed to sqlite3_declare_vtab(). For the first 63 columns (columns 0-62),
** the corresponding bit is set within the colUsed mask if the column may be
** required by SQLite. If the table has at least 64 columns and any column
** to the right of the first 63 is required, then bit 63 of colUsed is also
** set. In other words, column iCol may be required if the expression
** (colUsed & ((sqlite3_uint64)1 << (iCol>=63 ? 63 : iCol))) evaluates to
** non-zero.
**
** The [xBestIndex] method must fill aConstraintUsage[] with information
** about what parameters to pass to xFilter.  ^If argvIndex>0 then
** the right-hand side of the corresponding aConstraint[] is evaluated
** and becomes the argvIndex-th entry in argv.  ^(If aConstraintUsage[].omit
** is true, then the constraint is assumed to be fully handled by the
** virtual table and is not checked again by SQLite.)^
**
** ^The idxNum and idxPtr values are recorded and passed into the
** [xFilter] method.
** ^[sqlite3_free()] is used to free idxPtr if and only if
** needToFreeIdxPtr is true.
**
** ^The orderByConsumed means that output from [xFilter]/[xNext] will occur in
** the correct order to satisfy the ORDER BY clause so that no separate
** sorting step is required.
**
** ^The estimatedCost value is an estimate of the cost of a particular
** strategy. A cost of N indicates that the cost of the strategy is similar
** to a linear scan of an SQLite table with N rows. A cost of log(N)
** indicates that the expense of the operation is similar to that of a
** binary search on a unique indexed field of an SQLite table with N rows.
**
** ^The estimatedRows value is an estimate of the number of rows that
** will be returned by the strategy.
**
** The xBestIndex method may optionally populate the idxFlags field with a
** mask of SQLITE_INDEX_SCAN_* flags. Currently there is only one such flag -
** SQLITE_INDEX_SCAN_UNIQUE. If the xBestIndex method sets this flag, SQLite
** assumes that the strategy may visit at most one row.
**
** Additionally, if xBestIndex sets the SQLITE_INDEX_SCAN_UNIQUE flag, then
** SQLite also assumes that if a call to the xUpdate() method is made as
** part of the same statement to delete or update a virtual table row and the
** implementation returns SQLITE_CONSTRAINT, then there is no need to rollback
** any database changes. In other words, if the xUpdate() returns
** SQLITE_CONSTRAINT, the database contents must be exactly as they were
** before xUpdate was called. By contrast, if SQLITE_INDEX_SCAN_UNIQUE is not
** set and xUpdate returns SQLITE_CONSTRAINT, any database changes made by
** the xUpdate method are automatically rolled back by SQLite.
**
** IMPORTANT: The estimatedRows field was added to the sqlite3_index_info
** structure for SQLite [version 3.8.2] ([dateof:3.8.2]).
** If a virtual table extension is
** used with an SQLite version earlier than 3.8.2, the results of attempting
** to read or write the estimatedRows field are undefined (but are likely
** to included crashing the application). The estimatedRows field should
** therefore only be used if [sqlite3_libversion_number()] returns a
** value greater than or equal to 3008002. Similarly, the idxFlags field
** was added for [version 3.9.0] ([dateof:3.9.0]).
** It may therefore only be used if
** sqlite3_libversion_number() returns a value greater than or equal to
** 3009000.
*/
struct sqlite3_index_info {
  /* Inputs */
  int nConstraint;           /* Number of entries in aConstraint */
  struct sqlite3_index_constraint {
     int iColumn;              /* Column constrained.  -1 for ROWID */
     unsigned char op;         /* Constraint operator */
     unsigned char usable;     /* True if this constraint is usable */
     int iTermOffset;          /* Used internally - xBestIndex should ignore */
  } *aConstraint;            /* Table of WHERE clause constraints */
  int nOrderBy;              /* Number of terms in the ORDER BY clause */
  struct sqlite3_index_orderby {
     int iColumn;              /* Column number */
     unsigned char desc;       /* True for DESC.  False for ASC. */
  } *aOrderBy;               /* The ORDER BY clause */
  /* Outputs */
  struct sqlite3_index_constraint_usage {
    int argvIndex;           /* if >0, constraint is part of argv to xFilter */
    unsigned char omit;      /* Do not code a test for this constraint */
  } *aConstraintUsage;
  int idxNum;                /* Number used to identify the index */
  char *idxStr;              /* String, possibly obtained from sqlite3_malloc */
  int needToFreeIdxStr;      /* Free idxStr using sqlite3_free() if true */
  int orderByConsumed;       /* True if output is already ordered */
  double estimatedCost;           /* Estimated cost of using this index */
  /* Fields below are only available in SQLite 3.8.2 and later */
  long long int estimatedRows;    /* Estimated number of rows returned */
  /* Fields below are only available in SQLite 3.9.0 and later */
  int idxFlags;              /* Mask of SQLITE_INDEX_SCAN_* flags */
  /* Fields below are only available in SQLite 3.10.0 and later */
  long long unsigned int colUsed;    /* Input: Mask of columns used by statement */
};

]]

---@class sqlite3_index_constraint
---@field iColumn number @comment /* Column constrained.  -1 for ROWID */
---@field op number @comment /* Constraint operator */
---@field usable number @comment /* True if this constraint is usable */
---@field iTermOffset number @comment

---@class sqlite3_index_orderby
---@field iColumn number @comment /* Column number */
---@field desc number @comment /* True for DESC.  False for ASC. */

---@class sqlite3_index_constraint_usage
---@field argvIndex number @comment /* if >0, constraint is part of argv to xFilter */
---@field omit number @comment /* Do not code a test for this constraint */

---@class sqlite3_index_info
---@field nConstraint number
---@field aConstraint sqlite3_index_constraint[]
---@field nOrderBy number
---@field aOrderBy sqlite3_index_orderby[]
---@field aConstraintUsage sqlite3_index_constraint_usage[]
---@field  idxNum number @comment /* Number used to identify the index */
---@field idxStr string @comment /* String, possibly obtained from sqlite3_malloc */
---@field needToFreeIdxStr number @comment /* Free idxStr using sqlite3_free() if true */
---@field orderByConsumed number @comment /* True if output is already ordered */
---@field estimatedCost number @comment /* Estimated cost of using this index */
---@field estimatedRows number @comment /* Estimated number of rows returned */
---@field idxFlags number @comment /* Mask of SQLITE_INDEX_SCAN_* flags */
---@field colUsed number @comment /* Input: Mask of columns used by statement */

--[[
These are few "complex" callback methods needed by flexi_rel SQLite
virtual table. Refer to src/flexi/flexi_rel.cpp for more details
]]

---@param DBContext DBContext
---@param dbName string @comment main, temp...
---@param tableName string @comment new flexi_rel table name
---@param className string @comment class to be used as base
---@param propName string @comment reference property in className
---@param col1Name string @comment alias for column1 ("ObjectID" or "from")
---@param col2Name string @comment alias for column2 ("Value" or "to")
---@return number, string @comment ref property ID and  virtual table SQL definition if succeeds
---or throws error if fails
local function create_connect(DBContext, dbName, tableName, className, propName,
                              col1Name, col2Name)

    -- Normalize class and prop names
    className = normalizeSqlName(className)
    propName = normalizeSqlName(propName)
    col1Name = normalizeSqlName(col1Name)
    col2Name = normalizeSqlName(col2Name)

    -- check permission to create/open new tables
    DBContext.AccessControl:ensureUserCanCreateClass(DBContext.UserInfo)

    -- get class
    local classDef = DBContext:getClassDef(className, true)

    -- get property
    local propDef = classDef:getProperty(propName)

    -- ensure that this is reference property
    if not propDef:isReference() or propDef.D.refDef.mixin then
        error(string.format('[%s].[%s] must be a pure reference property', className, propName))
    end

    -->>
    generateView(DBContext, tableName, className, propName, col1Name, col2Name)

    -- TODO get "to" class and property


    -- set result SQL
    local result = string.format("create table [%s] ([%s], [%s], [%s_x] INT HIDDEN, [%s_x] INT HIDDEN) without rowid;",
            tableName, col1Name, col2Name, col1Name, col2Name)
    return propDef.ID, result
end

---@param DBContext DBContext
---@param propID number
---@param indexInfo sqlite3_index_info
local function best_index(DBContext, propID, indexInfo)
    ---@type sqlite3_index_info
    local info = ffi.cast('struct sqlite3_index_info *', indexInfo)
    if info.nConstraint > 0 then

    end

end

---@param DBContext DBContext
---@param propID number
---@param idxNum number
---@param idxStr string
---@param values any[]
local function filter(DBContext, propID, idxNum, idxStr, values)
    -- Build SQL based on filter
end

---@param DBContext DBContext
---@param propID number
---@param newRowID number
---@param oldRowID number
---@param fromID number
---@param toID number
---@param fromUDID string | number
---@param toUDID string | number
local function update(DBContext, propID, newRowID, oldRowID, fromID, toID, fromUDID, toUDID)

    -- Check propID

    -- Check DBContext

    -- Determine kind of operation, based on newID and oldID values


end

--[[Self test]]
local function selfTest()
    ---@type sqlite3_index_info
    local idxInfo = ffi.new 'struct sqlite3_index_info '
    idxInfo.nConstraint = 2
    idxInfo.aConstraint = ffi.new(string.format('struct sqlite3_index_constraint[%d]', idxInfo.nConstraint))
    idxInfo.aConstraint[0].iColumn = 5
    idxInfo.aConstraint[0].op = 3
    idxInfo.aConstraint[0].usable = 1
    idxInfo.aConstraint[1].iTermOffset = 20
    idxInfo.aConstraint[1].op = 31

    -- TODO check field offsets

    --print(idxInfo.aConstraint, idxInfo.aConstraint[0].op, idxInfo.aConstraint[0].iColumn, ffi.sizeof(idxInfo.aConstraint),
    --        idxInfo.aConstraint[1].op, idxInfo.aConstraint[1].iTermOffset)

    --local pIdxInfo = ffi.cast('struct sqlite3_index_info *', idxInfo)
    --print(ffi.sizeof(idxInfo))
    ---@type sqlite3_index_info
    --local ii = ffi.cast('struct sqlite3_index_info *', pIdxInfo)
    --ii.colUsed = 1
    --print(ii, ii.colUsed)
end

selfTest()

---@class FlexiRelVTable
---@field create_connect function
---@field best_index function
---@field filter function
---@field update function

return {
    create_connect = create_connect,
    best_index = best_index,
    filter = filter,
    update = update,
}


