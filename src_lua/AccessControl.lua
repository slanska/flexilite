---
--- Created by slanska.
--- DateTime: 2017-12-20 7:20 PM
---

--[[
Implements access control storage and permission verification
Used as a singleton object by DBContext
]]

local class = require 'pl.class'
local tablex = require 'pl.tablex'

---@class AccessControl
local AccessControl = class()

-- constructor
---@param DBContext DBContext
function AccessControl:_init(DBContext)
    self.DBContext = DBContext
end

--[[
Checks if given user's roles match given accessRules (coming from class, property, or object)
Returns true or false
accessRules may have 3 (optional) elements: roles, users, hook. If present, all of them are checked
to determine if there is any 'access denied' setting. 'Access denied' has highest priority
If userInfo or userInfo.roles is nil or empty, it is treated as '*' - access to everything
]]
---@param userInfo UserInfo
---@param accessRules table
---@param op string @comment One of these characters 'CRUDE' (Create, Read, Update, Delete, Execute)
---@return boolean
function AccessControl:checkUserPermission(userInfo, accessRules, op)

    local function checkPerm(permissions)
        local ch = string.match(permissions, '[N-]')
        if not ch then
            return false
        end

        ch = string.match(permissions, op)
        return ch ~= nil
    end

    local userRoles
    if not userInfo or not userInfo.roles then
        userRoles = { '*' }
    else
        userRoles = userInfo.userRoles
    end

    if accessRules then
        -- users
        if type(accessRules.users) == 'table' and accessRules.users[userInfo.ID] then
            if not checkPerm(accessRules.users[userInfo.ID]) then
                return false
            end
        end

        -- roles
        if type(accessRules.roles) == 'table' then
            -- Get intersection of accessRules.roles and userInfo.Roles
            local rr = tablex.intersection(accessRules.roles, userRoles)
            for roleName, rolePermissions in pairs(rr) do
                if not checkPerm(rolePermissions) then
                    return false
                end
            end
        end

        -- hook
        if type(accessRules.hook) == 'string' then
            -- TODO Call function by name. Check result
        end
    end

    return true
end

-- Similar to mayUser but throws 'Non authorized' error if mayUser returns false
-- Details are put into log TODO
---@param userInfo UserInfo
---@param accessRules table
---@param op string @comment One of these characters 'CRUDE' (Create, Read, Update, Delete, Execute)
function AccessControl:ensureUserPermission(userInfo, accessRules, op)
    local allowed = self:checkUserPermission(userInfo, accessRules, op)
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
function AccessControl:ensureCurrentUserAccessForClass(classID, op)
    local classDef = self.DBContext:getClassDef(classID)
    self.ensureUserPermission(self.DBContext.UserInfo, classDef.D.accessRules, op)
end

-- Ensures that current user has required permission for property level
function AccessControl:ensureCurrentUserAccessForProperty(propID, op)
    local propDef = self.DBContext.ClassProps[propID]
    assert(propDef)
    self.ensureUserPermission(self.DBContext.UserInfo, propDef.D.accessRules, op)
end

-- Reset temp data
function AccessControl:flushCache()
    self.ClassPermissions = {}
    self.PropPermissions = {}
end

return AccessControl