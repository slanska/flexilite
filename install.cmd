git submodule add https://github.com/torch/luajit-rocks.git ./lib/torch-lua
cd ./lib/torch-lua
mkdir build
cd build
cmake .. -DWITH_LUAJIT21=ON

rem *nix
sudo make install
rem windows
nmake install