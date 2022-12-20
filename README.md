# How does it work

This set of scripts creates a 60% faster LLVM toolchain that can be customly
trained to any project.

The full_workflow.bash will autodetect, if your machine supports LBR or not and choose the correct script which suits to your hardware.

## LLVM

### How to build

Be sure to have jemalloc installed, it is used to improve llvm-bolt's memory handling.

git clone https://github.com/ptr1337/llvm-bolt-scripts.git
cd llvm-bolt-scripts
./full_workflow.bash

This sequence will give you (hopefully) a faster LLVM toolchain.
Technologies used:

- LLVM Link Time Optimization (LTO)
- Binary Instrumentation and Profile-Guided-Optimization (PGO)
- perf-measurement and branch-sampling/profiling and final binary reordering (BOLT)

The goal of the techniques is to utilize the CPU black magic better and layout
the code in a way, that allows faster execution.

Measure performance gains and evaluate if its worth the hazzle :)
You can experiment with technologies, maybe `ThinLTO` is better than `FullLTO`,

For the last bit of performance, you can run several different workloads and then merge the resulted profiles with 'merge-fdata \*.fdata > combined.fdata' and then optimize the libary with llvm-bolt again.
and nothing else! The same goes for `BOLT`.

## GCC

If you want to bolt gcc, you need to disable when building gcc the language `lto`, you can still use the gcc lto function but gcc itself wont build with lto. Enabling lto will crash llvm-bolt.

Also you need to add following to your compileflags:

```
CXXFLAGS+="-fno-reorder-blocks-and-partition"
LDFLAGS+="--emit-relocs"
```

The compileflas should be used for any binary you compile and want to optimize the binary with bolt.

### Bolting other binarys/\*.so files

Ive included a script which makes it possible to bolt any binary or .so file which got compiled with --emit-relocs.
ust change the binary name and the path to your suits and the STAGE number.

After you did run stage 1 you need to run a workload with the instrumented binary/.so file.

When the workload is running, you will see that in the FDATA path many profiles are created. These will be in the STAGE2 process merged and then on your binary/.so file used and bolt will optimize it.

#### Example:

We will now take for example llvm:

    - Compile it with relocations (LDFLAGS+="--emit-relocs") enabled
    - Install your package
    - Change the to BINARY=libLLVM.so and the BINARYPATH=/usr/lib to your suits to the target you want to optimize and set STAGE=1
    - Run the script
    - After you did run it, it will backup your file and will move the instrumented target to the original path
    - Run a workload with the target, so compile something with clang
    - You will get several files into the FDATA path, when you run the workload !!! ATTENTION !!! the size of the data can get quite big, so take a watch at the folder
    - After youre done with the workload change at the script to STAGE=1
    - Run the script again and the created data from the instrumentiation will be merged and then used for llvm-bolt to optimize the target
    - After that it will automatically move it tor your systembinary/libary, a backup and the bolted binary can be found at the binarypath.
    - Thats it, now repeat the worklow for other targets you want top optimize.
    - Tip: if you for example instrumented libLLVM the profile is also useable for other llvm based files which where active in the recording process
