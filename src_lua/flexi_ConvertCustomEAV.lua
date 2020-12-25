---
--- Created by slanska.
--- DateTime: 2017-11-15 6:45 PM
---

--[[
select flexi('convert custom eav', params)

Convert custom EAV data to Flexi format
params =
{
classes: string | {propRef: string} | [string],
namespace: string | {propRef: string},
property: string | {propRef: string},
masterID: number | {propRef: string}
}

<namespace> and masterID are optional.
If set, will be used as prefix for top class name
<classes> define single or multiple class names
where value from <property> will go
<property> - source for value, direct property name as string or
name of property

]]