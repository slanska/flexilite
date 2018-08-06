## Build

### Windows

**Requirements:**

* MinGW has to be used for compiling Flexilite on Windows.

In Visual Studio Developer Command Prompt:
```shell    
cd <Flexilite_location>
cd .\lib\torch-l                    uajit-rocks
mkdir build
cd .\build
cmake .. -DCMAKE_INSTALL_PREFIX=c:\luajit21 -DWITH_LUAJIT21=ON -G "NMake Makefiles"  -DWIN32=1
nmake
rem install LuaJIT and LuaRocks
cmake  -DCMAKE_INSTALL_PREFIX=c:\luajit21 -DWITH_LUAJIT21=ON -G "NMake Makefiles"  -DWIN32=1 -P cmake_install.cmake
```

``` shell
cd .\lib\openresty-luajit2.1\src
mingw32-make BUILDMODE=static
```

### macOS

``` shell
cd <Flexilite_location>
cd ./lib/torch-luajit-rocks
mkdir ./build
cd ./build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr/torch -DWITH_LUAJIT21=ON 
make
```

To install Torch LuaJIT and LuaRocks run this command:
```
sudo make install
sudo /usr/torch/bin/luarocks install penlight
```

Add Torch binaries to PATH :

```shell
sudo nano ~/.profile
```

Append the following line to the end of file:

```shell
export PATH=$PATH:/usr/torch/bin 

```
 

### Linux (Ubuntu, Debian)

``` shell
cd <Flexilite_location>
cd ./lib/torch-luajit-rocks
mkdir ./build
cd ./build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr/torch -DWITH_LUAJIT21=ON 
make 
```
