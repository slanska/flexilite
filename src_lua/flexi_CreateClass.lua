---
--- Created by slanska.
--- DateTime: 2017-11-01 11:34 PM
---

local JSON = require('cjson')

local function CreateClass(DBContext, className, classDefAsJSONString, createVirtualTable)
    local classDef = JSON.decode(classDefAsJSONString)

    -- check if class with this name already exists

    -- validate name

    -- load class definition

    -- alter class definition

    local classNameID
    local stmt = DBContext:getStatement "insert into [.classes] (NameID, OriginalData) values (:1, :2);"
    stmt:reset()
    stmt:bind { [1] = classNameID, [2] = nil } -- TODO
    stmt:step()

    return 'Class [' .. className .. '] created'
end

return CreateClass