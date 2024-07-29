#!/bin/bash

## STAGE 1 = build llvm-bolt
## STAGE 2 = Instrument binary to run a workload with it to gather profiles for optimizing
## STAGE 3 = Merging the created data to one file and remove the not needed data## Actually bug in llvm-bolt https://github.com/llvm/llvm-project/issues/56209
## STAGE 4 = Optimize the binary with the created profile
STAGE=

## File or binary you want to instrument and then bolt
: ${BINARY:=libLLVM-14.so}

## PATH to the target
BINARYPATH=/usr/lib

## PATH where llvm-bolt is
BOLTPATH=~/toolchain/llvm/llvm-bolt/bin

## BASEDIR for data
TOPLEV=~/toolchain/bolt

## Here can be the optimized binarys,  merged fdata and your original binary/file as backup
BOLTBIN=${TOPLEV}/bin

## PATH FOR INTRUMENTED DATA
## Use a own PATH for it since it creates alot of files
FDATA=${TOPLEV}/fdata


################################################################
################################################################
################################################################
################################################################


create_path() {
    ## Create PATH's
    mkdir -p ${FDATA}
    mkdir -p ${BOLTBIN}
}

instrument() {

    echo "Instrument binary with llvm-bolt"
    LD_PRELOAD=/usr/lib/libjemalloc.so ${BOLTPATH}/llvm-bolt \
        --instrument \
        --instrumentation-file-append-pid \
        --instrumentation-file=${FDATA}/${BINARY}.fdata \
        ${BINARYPATH}/${BINARY} \
        -o ${BOLTBIN}/${BINARY} || (echo "Could not create instrumented binary"; exit 1)
    ## Backup original file
    sudo cp ${BINARYPATH}/${BINARY} ${BOLTBIN}/${BINARY}.org
    sudo cp ${BINARYPATH}/${BINARY} ${BINARYPATH}/${BINARY}.org
    ## Move instrumented and replace the original one with it for gathering easier a profile
    sudo cp ${BOLTBIN}/${BINARY} ${BINARYPATH}/${BINARY}
}

merge_fdata() {

    echo "Merging generated profiles"
    LD_PRELOAD=/usr/lib/libjemalloc.so ${BOLTPATH}/merge-fdata ${FDATA}/${BINARY}*.fdata > ${BOLTBIN}/${BINARY}-combined.fdata || (echo "Could not merge fdate"; exit 1)
    ## Removing not needed bloated fdata
    rm -rf ${FDATA}/${BINARY}*.fdata
}

optimize() {

    echo "Optimizing binary with generated profile"
    LD_PRELOAD=/usr/lib/libjemalloc.so ${BOLTPATH}/llvm-bolt ${BOLTBIN}/${BINARY}.org \
        --data ${BOLTBIN}/${BINARY}-combined.fdata \
        -o ${BOLTBIN}/${BINARY}.bolt \
        -reorder-blocks=ext-tsp
        -reorder-functions=cdsort
        -split-functions
        -split-all-cold
        -split-eh
        -dyno-stats
        -icf=1
        -use-gnu-stack
        -plt=hot || (echo "Could not optimize the binary"; exit 1)
}

move_binary() {

    echo "You can find now your optimzed binary at ${BOLTBIN}"
    sudo rm -rf ${FDATA}/${BINARY}.fdata*
    sudo cp ${BOLTBIN}/${BINARY}.bolt ${BINARYPATH}/${BINARY}
}

build_llvm_bolt ()  {

    TOPLEV=~/toolchain/llvm
    mkdir -p ${TOPLEV}
    cd ${TOPLEV} || (echo "Could not enter ${TOPLEV} directory"; exit 1)
    git clone --depth=1 https://github.com/llvm/llvm-project.git

    mkdir -p stage1 || (echo "Could not create stage1 directory"; exit 1)
    cd stage1 || (echo "Could not enter stage 1 directory"; exit 1)

    echo "== Configure Build"
    echo "== Build with system clang"

    cmake -G Ninja ${TOPLEV}/llvm-project/llvm \
        -DLLVM_BINUTILS_INCDIR=/usr/include \
        -DCMAKE_BUILD_TYPE=Release \
        -DCLANG_ENABLE_ARCMT=OFF \
        -DCLANG_ENABLE_STATIC_ANALYZER=OFF \
        -DCLANG_PLUGIN_SUPPORT=OFF \
        -DLLVM_ENABLE_BINDINGS=OFF \
        -DLLVM_ENABLE_OCAMLDOC=OFF \
        -DLLVM_INCLUDE_DOCS=OFF \
        -DLLVM_INCLUDE_EXAMPLES=OFF \
        -DCMAKE_C_COMPILER=clang \
        -DCMAKE_CXX_COMPILER=clang++ \
        -DLLVM_USE_LINKER=lld \
        -DLLVM_ENABLE_PROJECTS="clang;lld;bolt;compiler-rt" \
        -DLLVM_TARGETS_TO_BUILD="X86" \
        -DCMAKE_EXE_LINKER_FLAGS="-Wl,--push-state -Wl,-whole-archive -ljemalloc_pic -Wl,--pop-state -lpthread -lstdc++ -lm -ldl" \
        -DCMAKE_BUILD_TYPE=Release \
        -DLLVM_BUILD_UTILS=OFF \
        -DLLVM_ENABLE_BACKTRACES=OFF \
        -DLLVM_ENABLE_WARNINGS=OFF \
        -DLLVM_INCLUDE_TESTS=OFF \
        -DLLVM_ENABLE_TERMINFO=OFF \
        -DCMAKE_INSTALL_PREFIX=${TOPLEV}/llvm-bolt || (echo "Could not configure project!"; exit 1)

    echo "== Start Build"
    ninja install || (echo "Could not build project!"; exit 1)

}

## Stage 1
if [ "${STAGE}" = 1 ]; then
    build_llvm_bolt
fi

## Stage 2
if [ "${STAGE}" = 2 ]; then
    create_path
    instrument
fi

## Stage 3
if [ "${STAGE}" = 3 ]; then
    merge_fdata
fi
## Stage 4
if [ "${STAGE}" = 4 ]; then
    optimize
    move_binary
fi
