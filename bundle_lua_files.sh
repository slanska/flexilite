#!/usr/bin/env bash
for f in src_lua/*.lua; do
    luajit -b $f out_lua/`basename $f .lua`.o
done
ar rcus out_lua/libFlexiliteLua.a out_lua/*.o