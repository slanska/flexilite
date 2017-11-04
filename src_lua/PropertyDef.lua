---
--- Created by slanska.
--- DateTime: 2017-10-31 3:18 PM
---

--[[
Property definition
Keeps name, id, reference to class definition

]]

require 'math'

local PropertyDef = {}

function PropertyDef:new(ClassDef, name)
    local result = {
        ClassDef = ClassDef,
        name = name
    }

    setmetatable(result, self)
    self.__index = self

    return result
end

function PropertyDef:save()
    assert(self.ClassDef and self.ClassDef.DBContext)

    local stmt = self.ClassDef.DBContext.getStatement [[

    ]]

    stmt:bind {}
    local result = stmt:step()
    if result ~= 0 then
        -- todo error
    end
end

function PropertyDef:selfValidate()
    -- todo
end

--[[
Property type is defined as table of the following structure:
canChangeTo(newPropertyDef) -> 'yes', 'no', 'maybe' (data scan and validation needed)
isValidDef() -> bool
apply() [optional] applies definition (create index etc.)

]]

local BooleanType = {
    canChangeTo = function(self, newPropertyDef)

    end,

    isValidDef = function(self)

    end,

    apply = function(self)

    end
}

local IntegerType = {
    canChangeTo = function(self, newPropertyDef)

    end,

    isValidDef = function(self)

    end,

    apply = function(self)

    end
}

local NumberType = {
    canChangeTo = function(self, newPropertyDef)

    end,

    isValidDef = function(self)

    end,

    apply = function(self)

    end
}

local TextType = {
    canChangeTo = function(self, newPropertyDef)

    end,

    isValidDef = function(self)

    end,

    apply = function(self)

    end
}

local DateTimeType = {
    canChangeTo = function(self, newPropertyDef)

    end,

    isValidDef = function(self)

    end,

    apply = function(self)

    end
}

local UuidType = {
    canChangeTo = function(self, newPropertyDef)

    end,

    isValidDef = function(self)

    end,

    apply = function(self)

    end
}

local BytesType = {
    canChangeTo = function(self, newPropertyDef)

    end,

    isValidDef = function(self)

    end,

    apply = function(self)

    end
}

local EnumType = {
    canChangeTo = function(self, newPropertyDef)

    end,

    isValidDef = function(self)

    end,

    apply = function(self)

    end
}

local ReferenceType = {
    canChangeTo = function(self, newPropertyDef)

    end,

    isValidDef = function(self)

    end,

    apply = function(self)

    end
}

local NestedType = {
    canChangeTo = function(self, newPropertyDef)

    end,

    isValidDef = function(self)

    end,

    apply = function(self)

    end
}

local MixinType = {
    canChangeTo = function(self, newPropertyDef)

    end,

    isValidDef = function(self)

    end,

    apply = function(self)

    end
}

local SymNameType = {
    canChangeTo = function(self, newPropertyDef)

    end,

    isValidDef = function(self)

    end,

    apply = function(self)

    end
}

local MoneyType = {
    canChangeTo = function(self, newPropertyDef)

    end,

    isValidDef = function(self)

    end,

    apply = function(self)

    end
}

local JsonType = {
    canChangeTo = function(self, newPropertyDef)

    end,

    isValidDef = function(self)

    end,

    apply = function(self)

    end
}

local ComputedType = {
    canChangeTo = function(self, newPropertyDef)

    end,

    isValidDef = function(self)

    end,

    apply = function(self)

    end
}

-- map for property types
local propTypes = {
    ['bool'] = BooleanType,
    ['boolean'] = BooleanType,
    ['integer'] = IntegerType,
    ['int'] = IntegerType,
    ['number'] = NumberType,
    ['float'] = NumberType,
    ['text'] = TextType,
    ['string'] = TextType,
    ['string'] = TextType,
    ['bytes'] = BytesType,
    ['binary'] = BytesType,
    ['blob'] = BytesType,
    ['bytes'] = BytesType,
    ['decimal'] = MoneyType,
    ['money'] = MoneyType,
    ['uuid'] = UuidType,
    ['enum'] = EnumType,
    ['reference'] = ReferenceType,
    ['ref'] = ReferenceType,
    ['nested'] = NestedType,
    ['mixin'] = MixinType,
    ['json'] = JsonType,
    ['computed'] = ComputedType,
    ['formula'] = ComputedType,
    ['name'] = SymNameType,
    ['symname'] = SymNameType,
    ['symbol'] = SymNameType,
    ['date'] = DateTimeType,
    ['datetime'] = DateTimeType,
    ['time'] = DateTimeType,
    ['timespan'] = DateTimeType,

}

return PropertyDef