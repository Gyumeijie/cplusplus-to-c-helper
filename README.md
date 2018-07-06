# cplusplus-to-c-converter
This is a simple bash script to help converting code from c++ to c, whose object model is based on qemu object model.

# usage
- download the repository
```bash
git clone https://github.com/Gyumeijie/cplusplus-to-c-conversion-helper.git
```
- change into the examples directory and execute the converter.sh script
```bash
cd examples
./converter.sh
```
This script will converter the c++-style code to c-style code with [qemu object model](https://github.com/Gyumeijie/qemu-object-model) as its object model.

Caveats
> This is just helper script and you should not rely on it too much. It does spare some tedious works when rewriting c++ to c, but sometimes it also need your help to finish the remaining work. So as a suggesstion, you should always check the converted files.
