## Build

### Windows

**Requirements:**

* LuaJIT 2.0+ and LuaRocks installed and added to system PATH
* MinGW has to be used for compiling Flexilite on Windows.

``` shell
cd .\lib\openresty-luajit2.1\src
mingw32-make BUILDMODE=static
```

### macOS

``` shell
cd ./lib/openresty-luajit2/src
make BUILDMODE=static
```

### Linux (Ubuntu, Debian)

``` shell
cd ./lib/openresty-luajit2/src
make BUILDMODE=static
```
