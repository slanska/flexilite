--[[
Created by slanska on 2019-06-15.
]]

local path = require 'pl.path'

-- set lua paths
local paths = {
'../lib/lua-prettycjson/lib/resty/?.lua',
'../src_lua/?.lua',
'../lib/lua-sandbox/?.lua',
'../lib/lua-schema/?.lua',
'../lib/lua-date/?.lua',
'../lib/lua-metalua/?.lua',
'../lib/lua-metalua/compiler/?.lua',
'../lib/lua-metalua/compiler/bytecode/?.lua',
'../lib/lua-metalua/compiler/parser/?.lua',
'../lib/lua-metalua/extension/?.lua',
'../lib/lua-metalua/treequery/?.lua',
'../lib/lua-sandbox/?.lua',
'../lib/debugger-lua/?.lua',
'../?.lua',
}

for _, pp in ipairs(paths) do
    package.path = path.abspath(path.relpath(pp)) .. ';' .. package.path
end
