# Compile .lua files to static library, ready for link

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
        src_lua/EnumManager.lua
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
        src_lua/Constants.lua
        src_lua/AccessControl.lua
        src_lua/Util.lua
        src_lua/DBValue.lua
        src_lua/ApiGlobalObject.lua
        src_lua/ApiGlobalScope.lua
        src_lua/DBProperty.lua
        src_lua/ColMapping.lua

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

        # metalua-parser
        lib/lua-metalua/metalua/grammar/generator.lua
        lib/lua-metalua/metalua/grammar/lexer.lua
        lib/lua-metalua/metalua/compiler/parser.lua
        lib/lua-metalua/metalua/compiler/parser/common.lua
        lib/lua-metalua/metalua/compiler/parser/table.lua
        lib/lua-metalua/metalua/compiler/parser/ext.lua
        lib/lua-metalua/metalua/compiler/parser/annot/generator.lua
        lib/lua-metalua/metalua/compiler/parser/annot/grammar.lua
        lib/lua-metalua/metalua/compiler/parser/stat.lua
        lib/lua-metalua/metalua/compiler/parser/misc.lua
        lib/lua-metalua/metalua/compiler/parser/lexer.lua
        lib/lua-metalua/metalua/compiler/parser/meta.lua
        lib/lua-metalua/metalua/compiler/parser/expr.lua
        lib/lua-metalua/metalua/compiler.lua
        lib/lua-metalua/metalua/pprint.lua
        )

# Adding paths
execute_process(COMMAND mkdir -p "${CMAKE_CURRENT_SOURCE_DIR}/cmake-build-debug/lua/src_lua")
execute_process(COMMAND mkdir -p "${CMAKE_CURRENT_SOURCE_DIR}/cmake-build-debug/lua/lib/lua-prettycjson/lib/resty")
execute_process(COMMAND mkdir -p "${CMAKE_CURRENT_SOURCE_DIR}/cmake-build-debug/lua/lib/lua-schema")
execute_process(COMMAND mkdir -p "${CMAKE_CURRENT_SOURCE_DIR}/cmake-build-debug/lua/lib/lua-penlight/lua/pl")
execute_process(COMMAND mkdir -p "${CMAKE_CURRENT_SOURCE_DIR}/cmake-build-debug/lua/lib/lua-sandbox")
execute_process(COMMAND mkdir -p "${CMAKE_CURRENT_SOURCE_DIR}/cmake-build-debug/lua/lib/lua-metalua/metalua")
execute_process(COMMAND mkdir -p "${CMAKE_CURRENT_SOURCE_DIR}/cmake-build-debug/lua/lib/lua-metalua/metalua/compiler/bytecode")
execute_process(COMMAND mkdir -p "${CMAKE_CURRENT_SOURCE_DIR}/cmake-build-debug/lua/lib/lua-metalua/metalua/compiler/parser/annot")
execute_process(COMMAND mkdir -p "${CMAKE_CURRENT_SOURCE_DIR}/cmake-build-debug/lua/lib/lua-metalua/metalua/extension")
execute_process(COMMAND mkdir -p "${CMAKE_CURRENT_SOURCE_DIR}/cmake-build-debug/lua/lib/lua-metalua/metalua/grammar")
execute_process(COMMAND mkdir -p "${CMAKE_CURRENT_SOURCE_DIR}/cmake-build-debug/lua/lib/lua-metalua/metalua/treequery")

# Variable to store compiled Lua files
set(oLuaFiles)

# Generate commands to compile and embed Lua files
foreach (lua_file ${LUA_FILES})
    SET(oLuaFile "cmake-build-debug/lua/${lua_file}.o")

    # Compile .lua file to .obj
    if (${lua_file} STREQUAL "lib/lua-penlight/lua/pl/lexer.lua")
        #        execute_process(COMMAND luajit -bn "pl.lexer" "${CMAKE_CURRENT_SOURCE_DIR}/${lua_file}" "${CMAKE_CURRENT_SOURCE_DIR}/${oLuaFile}")
        ADD_CUSTOM_COMMAND(
                OUTPUT "${oLuaFile}"
                ALL
                WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
                COMMAND /torch/luajit/bin/luajit -bn "pl.lexer" "${CMAKE_CURRENT_SOURCE_DIR}/${lua_file}" "${CMAKE_CURRENT_SOURCE_DIR}/${oLuaFile}"
                #                COMMAND luajit -bn "pl.lexer" "${CMAKE_CURRENT_SOURCE_DIR}/${lua_file}" "${CMAKE_CURRENT_SOURCE_DIR}/${oLuaFile}"
                COMMENT "Compiling ${lua_file} to ${oLuaFile}"
                DEPENDS ${lua_file}
        )
    elseif (${lua_file} STREQUAL "lib/lua-metalua/metalua/grammar/lexer.lua")
        #        execute_process(COMMAND luajit -bn "metalua.grammar.lexer" "${CMAKE_CURRENT_SOURCE_DIR}/${lua_file}" "${CMAKE_CURRENT_SOURCE_DIR}/${oLuaFile}")
        ADD_CUSTOM_COMMAND(
                OUTPUT "${oLuaFile}"
                ALL
                WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
                COMMAND /torch/luajit/bin/luajit -bn "metalua.grammar.lexer" "${CMAKE_CURRENT_SOURCE_DIR}/${lua_file}" "${CMAKE_CURRENT_SOURCE_DIR}/${oLuaFile}"
                #                COMMAND luajit -bn "metalua.grammar.lexer" "${CMAKE_CURRENT_SOURCE_DIR}/${lua_file}" "${CMAKE_CURRENT_SOURCE_DIR}/${oLuaFile}"
                COMMENT "Compiling ${lua_file} to ${oLuaFile}"
                DEPENDS ${lua_file}
        )
    elseif (${lua_file} STREQUAL "lib/lua-metalua/metalua/compiler/parser/lexer.lua")
        #        execute_process(COMMAND luajit -bn "metalua.compiler.parser.lexer" "${CMAKE_CURRENT_SOURCE_DIR}/${lua_file}" "${CMAKE_CURRENT_SOURCE_DIR}/${oLuaFile}")
        ADD_CUSTOM_COMMAND(
                OUTPUT "${oLuaFile}"
                ALL
                WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
                COMMAND /torch/luajit/bin/luajit -bn "metalua.compiler.parser.lexer" "${CMAKE_CURRENT_SOURCE_DIR}/${lua_file}" "${CMAKE_CURRENT_SOURCE_DIR}/${oLuaFile}"
                #                COMMAND luajit -bn "metalua.compiler.parser.lexer" "${CMAKE_CURRENT_SOURCE_DIR}/${lua_file}" "${CMAKE_CURRENT_SOURCE_DIR}/${oLuaFile}"
                COMMENT "Compiling ${lua_file} to ${oLuaFile}"
                DEPENDS ${lua_file}
        )
    elseif (${lua_file} STREQUAL "lib/lua-metalua/metalua/grammar/generator.lua")
        #        execute_process(COMMAND luajit -bn "metalua.grammar.generator" "${CMAKE_CURRENT_SOURCE_DIR}/${lua_file}" "${CMAKE_CURRENT_SOURCE_DIR}/${oLuaFile}")
        ADD_CUSTOM_COMMAND(
                OUTPUT "${oLuaFile}"
                ALL
                WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
                COMMAND /torch/luajit/bin/luajit -bn "metalua.grammar.generator" "${CMAKE_CURRENT_SOURCE_DIR}/${lua_file}" "${CMAKE_CURRENT_SOURCE_DIR}/${oLuaFile}"
                #                COMMAND luajit -bn "metalua.grammar.generator" "${CMAKE_CURRENT_SOURCE_DIR}/${lua_file}" "${CMAKE_CURRENT_SOURCE_DIR}/${oLuaFile}"
                COMMENT "Compiling ${lua_file} to ${oLuaFile}"
                DEPENDS ${lua_file}
        )
    elseif (${lua_file} STREQUAL "lib/lua-metalua/metalua/compiler/parser/annot/generator.lua")
        #        execute_process(COMMAND luajit -bn "metalua.compiler.parser.annot.generator" "${CMAKE_CURRENT_SOURCE_DIR}/${lua_file}" "${CMAKE_CURRENT_SOURCE_DIR}/${oLuaFile}")
        ADD_CUSTOM_COMMAND(
                OUTPUT "${oLuaFile}"
                ALL
                WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
                COMMAND /torch/luajit/bin/luajit -bn "metalua.compiler.parser.annot.generator" "${CMAKE_CURRENT_SOURCE_DIR}/${lua_file}" "${CMAKE_CURRENT_SOURCE_DIR}/${oLuaFile}"
                #                COMMAND luajit -bn "metalua.compiler.parser.annot.generator" "${CMAKE_CURRENT_SOURCE_DIR}/${lua_file}" "${CMAKE_CURRENT_SOURCE_DIR}/${oLuaFile}"
                COMMENT "Compiling ${lua_file} to ${oLuaFile}"
                DEPENDS ${lua_file}
        )
    else ()
        #        execute_process(COMMAND luajit -b "${CMAKE_CURRENT_SOURCE_DIR}/${lua_file}" "${CMAKE_CURRENT_SOURCE_DIR}/${oLuaFile}")
        ADD_CUSTOM_COMMAND(
                OUTPUT "${oLuaFile}"
                ALL
                WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
                COMMAND /torch/luajit/bin/luajit -b "${CMAKE_CURRENT_SOURCE_DIR}/${lua_file}" "${CMAKE_CURRENT_SOURCE_DIR}/${oLuaFile}"
                #                COMMAND luajit -b "${CMAKE_CURRENT_SOURCE_DIR}/${lua_file}" "${CMAKE_CURRENT_SOURCE_DIR}/${oLuaFile}"
                COMMENT "Compiling ${lua_file} to ${oLuaFile}"
                DEPENDS ${lua_file}
        )
    endif ()

    SET(luaTarget)
    STRING(MAKE_C_IDENTIFIER ${lua_file} luaTarget)

    set(oLuaFiles ${oLuaFiles} ${oLuaFile})
    set_source_files_properties(${oLuaFile} PROPERTIES GENERATED TRUE)
endforeach (lua_file)

ADD_CUSTOM_TARGET(
        OUTPUT "${CMAKE_CURRENT_SOURCE_DIR}/libLuaModules.a"
        COMMAND ar rcus "${CMAKE_CURRENT_SOURCE_DIR}/libLuaModules.a" "${CMAKE_CURRENT_SOURCE_DIR}/cmake-build-debug/lua//*.o"
        COMMENT "Building Lua Modules Library"
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
)
#        ADD_CUSTOM_COMMAND (
#        OUTPUT "${CMAKE_CURRENT_SOURCE_DIR}/libLuaModules.a"
#        COMMAND ar rcus "${CMAKE_CURRENT_SOURCE_DIR}/libLuaModules.a" "${CMAKE_CURRENT_SOURCE_DIR}/cmake-build-debug/lua//*.o"
#        COMMENT "Building Lua Modules Library"
#        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
#)
