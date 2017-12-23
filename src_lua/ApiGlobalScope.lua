---
--- Created by slanska.
--- DateTime: 2017-12-22 8:37 PM
---

--[[
    Provides access to global scope for custom functions executed in sandbox
 Implemented as table with metamethods to provide on-demand access
 The following pseudo-global attributes are available (depending on context):
 - data (when running as object's method)
 - old and new (when running in trigger)

 - db DBContext with <Classes and Functions>
 - pl (Penlight library)
 - json
 - xml
 - yaml
 - standard math, string and table API
]]