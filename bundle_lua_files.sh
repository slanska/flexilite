#!/usr/bin/env bash
for f in src_lua/*.lua; do
    luajit -b $f out_lua/`basename $f .lua`.o
done
ar rcus out_lua/libFlexiliteLua.a out_lua/*.o

# Then link the libmyluafiles.a library into your main program using -Wl,--whole-archive -lmyluafiles -Wl,--no-whole-archive -Wl,-E.
# This line forces the linker to include all object files from the archive and to export all symbols.
# For example, a file named foo.lua can now be loaded with local foo = require("foo") from within your application.