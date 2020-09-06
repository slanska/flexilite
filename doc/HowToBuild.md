## Build LuaJIT

### Windows

In Visual Studio Developer Command Prompt:
```shell    
cd <Flexilite_location>
copy .\luajit_msvcbuild.bat .\lib\torch-luajit-rocks\luajit-2.1\src\msvcbuild.bat
cd .\lib\torch-luajit-rocks\luajit-2.1\src
setenv /release /x86
or
setenv /release /x64
msvcbuild static
```

### macOS

Flexilite uses fork of LuaJIT from Torch and expects the latest Xcode and its tools
to be installed to compile LuaJIT. 

``` shell
cd <Flexilite_location>
cd ./lib/torch-luajit-rocks
mkdir -p ./build
cd ./build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local/etc/torch -DWITH_LUAJIT21=ON 
make
```

If you are getting error about math.h or other header files not found, try to run the
following command before make:
``` shell
export CPATH=`xcrun --show-sdk-path`/usr/include
```

To install Torch LuaJIT and LuaRocks run this command:
```
sudo make install
cd /usr/local/etc/torch/bin
sudo luarocks install penlight
sudo luarocks install busted
```

If installing Luarocks fails, try to clean up .luarocks folder:

```
sudo rm -rf ~/.cache/luarocks
```

Also, make sure that wget is installed:

```
brew install wget
```

Add Torch binaries to PATH :

```shell
sudo nano ~/.profile
```

Append the following line to the end of file:

```shell
export PATH=$PATH:/usr/local/etc/torch/bin 
```
 

### Linux (Ubuntu, Debian)

``` shell
sudo apt-get install libc6-dbg gdb valgrind
```

``` shell
cd <Flexilite_location>
cd ./lib/torch-luajit-rocks
mkdir ./build
cd ./build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr/torch -DWITH_LUAJIT21=ON 
make 
```

### Install dependencies

```shell
cd ./lib/debugger-lua && luajit embed/debugger.c.lua
```

## Test

[busted](https://github.com/Olivine-Labs/busted) is used to run Flexilite tests

Since by default **busted** expects Lua 5.3, and Flexilite is based on LuaJIT 2.1,
it needs to run with the following setting:

```shell
busted --lua=<PATH_TO_LUAJIT> test.lua
```
