
cmake_minimum_required(VERSION 2.8)

enable_testing()

if (WIN32)
    add_definitions(-D_CRT_SECURE_NO_WARNINGS)
endif ()

function(PROCESS_LUA_FILE, LuaFile)
    get_filename_component(LuaFile)
    if ()

    endif ()
endfunction(PROCESS_LUA_FILE)

# Include .lua and .C sources

set(LUA_FILES
        )

set(SOURCE
        main.c

        )

# sqlite
# luajit
# lua-cjson
# luasqlite3complete
# base63
# penlight

# lua sources