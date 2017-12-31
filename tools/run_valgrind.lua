---
--- Created by slanska.
--- DateTime: 2017-12-30 12:53 PM
---

--[[
    git submodule init & git submodule update


]]

local os = require 'os'
os.execute ('cd ../cmake-build-debug/bin && valgrind --leak-check=full --track-origins=yes ./flexilite_test')