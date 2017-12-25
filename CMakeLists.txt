cmake_minimum_required(VERSION 2.8)

enable_testing()

if (WIN32)
    add_definitions(-D_CRT_SECURE_NO_WARNINGS)
endif ()

#CMake provides three variables to describe the system:
#
#CMAKE_SYSTEM_NAME (Window, Linux, Darwin),
#CMAKE_SYSTEM_PROCESSOR (depends on the OS, for instance i386 on Linux, x86 on Windows, etc.)
#CMAKE_SYSTEM_VERSION (depends on the OS too)

set(CMAKE_BINARY_DIR "${CMAKE_CURRENT_SOURCE_DIR}")

#message(WARNING "Platform: ${CMAKE_SYSTEM_NAME}-${CMAKE_SYSTEM_PROCESSOR}")
#message(WARNING "Platform: ${CMAKE_SYSTEM_NAME}-${CMAKE_SYSTEM_PROCESSOR}-${PLATFORM}")
set(PLATFORM "${CMAKE_SYSTEM_NAME}")
string(TOUPPER "${PLATFORM}" PLATFORM)

#set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin/${CMAKE_SYSTEM_NAME}-${CMAKE_SYSTEM_PROCESSOR})
#set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin/${CMAKE_SYSTEM_NAME}-${CMAKE_SYSTEM_PROCESSOR})
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

project(sqlite_shell)

message("Building on: ${CMAKE_SYSTEM_NAME}")

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if (${CMAKE_SYSTEM_NAME} MATCHES "Windows")
    find_package(zlib REQUIRED)
else ()
    find_package(ZLIB REQUIRED)
endif ()

find_package(Threads REQUIRED)

set(SHELL_FILES
        lib/sqlite/shell.c
        lib/sqlite/sqlite3.c
        )

add_definitions(-DSQLITE_ENABLE_FTS4
        -DSQLITE_ENABLE_RTREE
        -DSQLITE_ENABLE_LOAD_EXTENSION
        -DSQLITE_ENABLE_JSON1)

add_executable(sqlite_shell ${SHELL_FILES})

# Note libraries are linked AFTER executable is registered
# also, using 'm' for standard math library
target_link_libraries(sqlite_shell ${CMAKE_THREAD_LIBS_INIT} ${CMAKE_DL_LIBS})
target_link_libraries(sqlite_shell m)

# libFlexilite library
project(Flexilite)

include_directories(
        lib/sqlite
        lib/luajit-2.1/src
        src/util
)

add_custom_target(Generate_Resources
        ALL
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        COMMAND xxd -i sql/dbschema.sql > src/resources/dbschema.res.h
        COMMENT "Generating resource file for SQL schema."
        DEPENDS sql/dbschema.sql)

set_source_files_properties(src/resources/dbschema.res.h PROPERTIES GENERATED TRUE)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_definitions(-DRESOURCES_GENERATED
        )

set(LUA_FILES
        # src_lua/
        src_lua/NameRef.lua
        src_lua/UserInfo.lua
        src_lua/flexi_CreateClass.lua
        src_lua/flexi_DropClass.lua
        src_lua/flexi_SplitProperty.lua
        src_lua/ClassDef.lua
        src_lua/flexi_AlterClass.lua
        src_lua/flexi_CreateProperty.lua
        src_lua/flexi_DropProperty.lua
        src_lua/flexi_StructuralMerge.lua
        src_lua/DBContext.lua
        src_lua/PropertyDef.lua
        src_lua/flexi_AlterProperty.lua
        src_lua/flexi_DataBestIndex.lua
        src_lua/flexi_MergeProperty.lua
        src_lua/flexi_StructuralSplit.lua
        src_lua/EnumDef.lua
        src_lua/QueryBuilder.lua
        src_lua/flexi_Configure.lua
        src_lua/flexi_DataFilter.lua
        src_lua/flexi_ObjectToProp.lua
        src_lua/index.lua
        src_lua/JulianDate.lua
        src_lua/Triggers.lua
        src_lua/flexi_ConvertCustomEAV.lua
        src_lua/flexi_DataUpdate.lua
        src_lua/flexi_PropToObject.lua
        src_lua/DBObject.lua
        src_lua/ApiObject.lua
        src_lua/Constants.lua
        src_lua/ApiProperty.lua
        src_lua/AccessControl.lua
        src_lua/DBCell.lua
        src_lua/Util.lua
        src_lua/ApiGlobalObject.lua
        src_lua/ApiGlobalScope.lua

        #lib
        lib/lua-prettycjson/lib/resty/prettycjson.lua
        lib/lua-schema/schema.lua

        #penlight
        lib/lua-penlight/lua/pl/Date.lua
        lib/lua-penlight/lua/pl/Set.lua
        lib/lua-penlight/lua/pl/comprehension.lua
        lib/lua-penlight/lua/pl/func.lua
        lib/lua-penlight/lua/pl/lexer.lua
        lib/lua-penlight/lua/pl/pretty.lua
        lib/lua-penlight/lua/pl/stringx.lua
        lib/lua-penlight/lua/pl/types.lua
        lib/lua-penlight/lua/pl/List.lua
        lib/lua-penlight/lua/pl/app.lua
        lib/lua-penlight/lua/pl/config.lua
        lib/lua-penlight/lua/pl/import_into.lua
        lib/lua-penlight/lua/pl/luabalanced.lua
        lib/lua-penlight/lua/pl/seq.lua
        lib/lua-penlight/lua/pl/tablex.lua
        lib/lua-penlight/lua/pl/url.lua
        lib/lua-penlight/lua/pl/Map.lua
        lib/lua-penlight/lua/pl/array2d.lua
        lib/lua-penlight/lua/pl/data.lua
        lib/lua-penlight/lua/pl/init.lua
        lib/lua-penlight/lua/pl/operator.lua
        lib/lua-penlight/lua/pl/sip.lua
        lib/lua-penlight/lua/pl/template.lua
        lib/lua-penlight/lua/pl/utils.lua
        lib/lua-penlight/lua/pl/MultiMap.lua
        lib/lua-penlight/lua/pl/class.lua
        lib/lua-penlight/lua/pl/dir.lua
        lib/lua-penlight/lua/pl/input.lua
        lib/lua-penlight/lua/pl/path.lua
        lib/lua-penlight/lua/pl/strict.lua
        lib/lua-penlight/lua/pl/test.lua
        lib/lua-penlight/lua/pl/xml.lua
        lib/lua-penlight/lua/pl/OrderedMap.lua
        lib/lua-penlight/lua/pl/compat.lua
        lib/lua-penlight/lua/pl/file.lua
        lib/lua-penlight/lua/pl/lapp.lua
        lib/lua-penlight/lua/pl/permute.lua
        lib/lua-penlight/lua/pl/stringio.lua
        lib/lua-penlight/lua/pl/text.lua

        # sandbox
        lib/lua-sandbox/sandbox.lua
        )

execute_process(COMMAND mkdir -p "${CMAKE_CURRENT_SOURCE_DIR}/cmake-build-debug/lua/src_lua")
execute_process(COMMAND mkdir -p "${CMAKE_CURRENT_SOURCE_DIR}/cmake-build-debug/lua/lib/lua-prettycjson/lib/resty")
execute_process(COMMAND mkdir -p "${CMAKE_CURRENT_SOURCE_DIR}/cmake-build-debug/lua/lib/lua-schema")
execute_process(COMMAND mkdir -p "${CMAKE_CURRENT_SOURCE_DIR}/cmake-build-debug/lua/lib/lua-penlight/lua/pl")
execute_process(COMMAND mkdir -p "${CMAKE_CURRENT_SOURCE_DIR}/cmake-build-debug/lua/lib/lua-sandbox")

# Variable to store compiled Lua files
set(oLuaFiles)

# Generate commands to compile and embed Lua files
foreach (lua_file ${LUA_FILES})
    MESSAGE(STATUS "Generating Lua compile for ${lua_file}")
    SET(oLuaFile "cmake-build-debug/lua/${lua_file}.o")
    execute_process(COMMAND luajit -b "${CMAKE_CURRENT_SOURCE_DIR}/${lua_file}" "${CMAKE_CURRENT_SOURCE_DIR}/${oLuaFile}")

    SET(luaTarget)
    STRING(MAKE_C_IDENTIFIER ${lua_file} luaTarget)

    ADD_CUSTOM_COMMAND(
            OUTPUT "${oLuaFile}"
            ALL
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
            COMMAND luajit -b "${lua_file}" "${oLuaFile}"
            COMMENT "Compiling ${lua_file}.lua to .o"
            DEPENDS ${lua_file}
    )
    set(oLuaFiles ${oLuaFiles} ${oLuaFile})
    set_source_files_properties(${oLuaFile} PROPERTIES GENERATED TRUE)
endforeach (lua_file)

ADD_CUSTOM_COMMAND(
        OUTPUT "${CMAKE_CURRENT_SOURCE_DIR}/libLuaModules.a"
        COMMAND ar rcus "${CMAKE_CURRENT_SOURCE_DIR}/libLuaModules.a" "${CMAKE_CURRENT_SOURCE_DIR}/cmake-build-debug/lua/src_lua/*.o"
        COMMENT "Building Lua Modules Library"
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
)

set(EXT_FILES
        # version of lsqlite for extension library (using sqlite3ext.h instead of sqlite3.h)
        src/lua-sqlite/lsqlite3.c
        lib/lua-cjson/fpconv.c
        lib/lua-cjson/lua_cjson.c
        lib/lua-cjson/strbuf.c
        src/misc/json1.c
        src/typings/DBDefinitions.h
        src/project_defs.h
        src/main.cpp

        # compress.c is temporarily disabled because of the following error: Undefined symbols for architecture x86_64:
        #        "_compress", referenced from:
        #        src/misc/compress.c
        src/misc/eval.c
        src/misc/fileio.c
        src/misc/regexp.c
        src/misc/totype.c
        #        src/_old_flexilite/flexi_get.c
        src/misc/var.c

        src/util/hash.c

        src/misc/hash.c

        src/misc/memstat.c
        #        src/flexi/flexi_data.cpp

        #        src/flexi/flexi_class.cpp
        #        src/flexi/flexi_class_alter.cpp
        #        src/flexi/flexi_props_to_object.c

        src/fts/fts3_expr.c
        src/fts/fts3_tokenizer.c
        src/fts/fts3_hash.c
        #        src/flexi/flexi_prop.c
        #        src/flexi/flexi_prop_merge.c
        #        src/flexi/flexi_query.cpp
        #        src/util/json_proc.c
        src/common/common.h
        src/util/Array.c
        src/util/Array.h
        src/flexi/flexi_func.cpp

        #        src/flexi/flexi_prop_merge.h
        #        src/flexi/flexi_db_ctx.cpp
        #        src/flexi/flexi_db_ctx.h
        #        src/flexi/flexi_UserInfo_t.c
        #        src/flexi/flexi_UserInfo_t.h
        #        src/util/rbtree.c
        #        src/flexi/class_ref_def.c
        #        src/flexi/class_ref_def.h
        #        src/util/List.c
        #        src/util/List.h
        src/util/Path.c
        src/util/Path.h
        src/util/StringBuilder.c
        src/util/StringBuilder.h
        #        src/flexi/flexi_data_adhoc.c
        #        src/flexi/flexi_data_vtable.c
        #        src/flexi/class_build_json.c
        #        src/flexi/flexi_data.h
        #        src/flexi/flexi_Object.c
        #        src/flexi/flexi_Object.h
        #        src/flexi/flexi_PropValue.c
        #        src/flexi/flexi_PropValue.h
        #        src/flexi/DBContext.cpp
        #        src/flexi/DBContext.h
        src/flexi/ClassDef.cpp
        src/flexi/ClassDef.h
        src/flexi/PropertyDef.cpp
        src/flexi/PropertyDef.h
        flexish/main.c
        ${oLuaFiles}
        )

#set(CMAKE_FIND_LIBRARY_SUFFIXES ".so")
#set(CMAKE_FIND_LIBRARY_SUFFIXES ".dylib")
#set(CMAKE_FIND_LIBRARY_SUFFIXES ".dll")
set(CMAKE_FIND_LIBRARY_PREFIXES "")

# Register Flexilite DLL/SO/DYLIB
# Link to luajit statically

add_subdirectory(lib/luajit-2.1)

add_library(Flexilite SHARED ${EXT_FILES})

target_link_libraries(Flexilite PUBLIC luajit-static)

add_custom_target(install_${PROJECT_NAME}
        make install
        DEPENDS ${PROJECT_NAME}
        COMMENT "Installing ${PROJECT_NAME}")

add_subdirectory(test)