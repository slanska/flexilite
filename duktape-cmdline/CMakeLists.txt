cmake_minimum_required(VERSION 3.5)

enable_testing()

set(PLATFORM "${CMAKE_SYSTEM_NAME}")
string(TOUPPER "${PLATFORM}" PLATFORM)

set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

project(duktape)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)


include_directories(
        ../lib/duktape
)

add_definitions(

        -DDUK_USE_DEBUGGER_SUPPORT
        -DDUK_USE_INTERRUPT_COUNTER
        -DDUK_CMDLINE_DEBUGGER_SUPPORT
)

set(DUK_FILES
        duk_cmdline.c
        duk_cmdline.h
        duk_cmdline_lowmem.c
        duk_trans_socket.h
#        duk_trans_socket_windows.c
        duk_trans_socket_unix.c
        ../lib/duktape/duktape.c
        ../lib/duktape/duktape.h
        ../lib/duktape/duk_config.h
        )

add_executable(duktape ${DUK_FILES})

target_link_libraries(duktape ${CMAKE_THREAD_LIBS_INIT} ${CMAKE_DL_LIBS})
