* luarocks install luafilesystem
* luarocks install mobdebug
* luarocks install busted
* luarocks install penlight


**Example of adding a new submodule:**

git submodule add MODULE_URL lib/LOCAL_MODULE_PATH

```shell
git rm --cached projectfolder
```


Update all submodules:
```shell
cd ./lib
git submodule init
git submodule update --force --merge --remote
```

**Update git submodules**
```shell
git submodule update --remote --merge --init 
```
