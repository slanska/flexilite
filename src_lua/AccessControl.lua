---
--- Created by slanska.
--- DateTime: 2017-12-20 7:20 PM
---

--[[
Implements access control storage and permission verification
Used as a singleton object by DBContext
]]

local class = require 'pl.class'

---@class AccessControl
local AccessControl = class()

-- constructor
---@param DBContext DBContext
function AccessControl:_init(DBContext)
    self.DBContext = DBContext
    self.ClassPermissions = {}
    self.PropPermissions = {}
end

---@param userInfo UserInfo
---@param accessRules table
---@param op string @comment One of these characters 'CRUDE' (Create, Read, Update, Delete, Execute)
---@return boolean
function AccessControl:mayUser(userInfo, accessRules, op)
    if accessRules then
        -- roles
        if type(accessRules.roles) == 'table' then

        end

        -- users
        if type(accessRules.users) == 'table' then

        end

        -- hook
        if type(accessRules.hook) == 'string' then

        end
    end

    return true
end

-- Similar to mayUser but throws 'Non authorized' error if mayUser returns false
-- Details are put into log TODO
---@param userInfo UserInfo
---@param accessRules table
---@param op string @comment One of these characters 'CRUDE' (Create, Read, Update, Delete, Execute)
function AccessControl:ensureUserMay(userInfo, accessRules, op)
    local allowed = self:mayUser(userInfo, accessRules, op)
    if not allowed then
        -- TODO Log details
        error('Not authorized')
    end
end

-- Get aggregated permissions for the given accessRules
---@param accessRules IAccessRules
function AccessControl:getPermissions(accessRules)

end

-- Ensures that current user has required permission for class level
function AccessControl:ensureCurrentUserAccessForClass(classDef, op)
    local result = self.ClassPermissions[classDef.ClassID]
    if result then

    end

    local perms = self:getPermissions(classDef.D.accessRules)
    self.mayUser(self.DBContext.UserInfo, classDef.D.accessRules, op)
end

-- Ensures that current user has required permission for property level
function AccessControl:ensureCurrentUserAccessForProperty(propDef, op)

end

-- Reset temp data
function AccessControl:flushCache()
    self.ClassPermissions = {}
    self.PropPermissions = {}
end

return AccessControl