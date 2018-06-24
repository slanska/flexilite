* luarocks install luafilesystem
* luarocks install bit32
* luarocks install lua-cjson
* luarocks install lsqlite3
* luarocks install lsqlite3complete
* luarocks install mobdebug
* luarocks install luasocket
* luarocks install luacheck
* luarocks install busted
* luarocks install penlight
* luarocks install schema
* luarocks install prettycjson
* luarocks install ansicolors



Update all submodules:
```
cd ./lib
git submodule init
git submodule update --force --merge
``'

**Update git submodules**
```
git submodule update --remote --merge --init 
```