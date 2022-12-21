# Introduction

These scripts create a custom-trained LLVM toolchain that is 60% faster for any project. The full_workflow.bash script will automatically detect if your machine supports LBR (Last Branch Record) and choose the appropriate script.

# Technologies Used

- LLVM Link Time Optimization (LTO)
- Binary Instrumentation and Profile-Guided Optimization (PGO)
- perf-measurement, branch-sampling/profiling, and final binary reordering (BOLT)

The goal of these techniques is to make better use of the CPU's resources and layout the code in a way that allows for faster execution.

# Prerequisites

Be sure to have jemalloc installed, as it is used to improve llvm-bolt's memory handling.

# Building LLVM

To build the toolchain, follow these steps:

Clone the repository: `git clone <https://github.com/ptr1337/llvm-bolt-scripts.git>`
Navigate to the repository directory: `cd llvm-bolt-scripts`
Run the full workflow script: `./full_workflow.bash`
This process should give you a faster LLVM toolchain. You can experiment with different technologies (e.g. ThinLTO vs FullLTO) and measure the performance gains to determine if it is worth the effort.

To further optimize the library, you can run several different workloads and then merge the resulting profiles using `merge-fdata *.fdata > combined.fdata`. Then, run `llvm-bolt` on the library again.

# Building GCC

To bolt GCC, you need to disable the language `lto` when building GCC. You can still use the GCC LTO function, but GCC itself will not build with LTO. Enabling LTO will cause `llvm-bolt` to crash.

In addition, you need to add the following flags to your compile flags:

```C
CXXFLAGS+="-fno-reorder-blocks-and-partition"
LDFLAGS+="--emit-relocs"
```

These flags should be used for any binary you want to optimize with bolt.

# Bolting Other Binary/`.so` Files

There is a script included that allows you to bolt any binary or `.so` file that was compiled with `--emit-relocs`. To use it, simply change the binary name and path to suit your needs and the stage number.

After running stage 1, you will need to run a workload with the instrumented binary/`.so` file. During the workload, you will see that profiles are created in the FDATA path. These profiles will be merged in the STAGE2 process and then used on your binary/`.so` file to optimize it with bolt.

#### Example:

We will now take for example llvm:

```
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
```
