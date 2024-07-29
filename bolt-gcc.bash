#!/bin/bash

## Change here to your gcc version, you can find it with gcc -v "/usr/lib/gcc/x86_64-pc-linux-gnu/12"
GCCVER=12
## Base
TOPLEV=~/toolchain/gcc
## PATH for instrument data, when bolting without perf
DATA=${TOPLEV}/instrument
## GCC binary path to bolt
GCCPATH=/usr/lib/gcc/x86_64-pc-linux-gnu/${GCCVER}
## PATH where bolt is
BOLTPATH=~/toolchain/llvm/stage1/install/bin
## Change here the path to your perf.data if you have a cpu which supports LBR
## You need before running the script the perf.data with that command example:
## perf record -o perf.data -e cycles:u -j any,u -- 'command to run for example: make'
PERFDATA=/home/foo/perf.data
## Set here the stage you want to run
## STAGE 1 creates a instrumented binary, with that you need to run a workload to get profile data
## Stage 2 there we use llvm-bolt top optimize the binary
STAGE=


mkdir -p ${DATA}/cc1
mkdir -p ${DATA}/cc1plus



if [ ${STAGE} = 1 ]; then
    echo "Instrument clang with llvm-bolt"

    LD_PRELOAD=/usr/lib/libjemalloc.so ${BOLTPATH}/llvm-bolt \
        --instrument \
        --instrumentation-file-append-pid \
        --instrumentation-file=${DATA}/cc1/cc1.fdata \
        ${GCCPATH}/cc1 \
        -o ${DATA}/cc1/cc1

    LD_PRELOAD=/usr/lib/libjemalloc.so ${BOLTPATH}/llvm-bolt \
        --instrument \
        --instrumentation-file-append-pid \
        --instrumentation-file=${DATA}/cc1plus/cc1plus.fdata \
        ${GCCPATH}/cc1plus \
        -o ${DATA}/cc1plus/cc1plus
    #echo "mooving instrumented binary"
    sudo mv ${GCCPATH}/cc1 ${GCCPATH}/cc1.org
    sudo mv ${DATA}/cc1/cc1 ${GCCPATH}/cc1
    #echo "mooving instrumented binary"
    sudo mv ${GCCPATH}/cc1plus ${GCCPATH}/cc1plus.org
    sudo mv ${DATA}/cc1plus/cc1plus ${GCCPATH}/cc1plus

    echo "Now move the binarys to the gcc path"
    echo "now do some instrument compiles for example compiling a kernel or GCC"
fi

if [ ${STAGE} = 2 ]; then
    echo "Instrument clang with llvm-bolt"

    ## Check if perf is available
    perf record -e cycles:u -j any,u -- sleep 1 &>/dev/null;

    if [[ $? == "0" ]]; then
        echo "BOLTING with Profile!"

        LD_PRELOAD=/usr/lib/libjemalloc.so ${BOLTPATH}/perf2bolt ${GCCPATH}/cc1.org \
            -p ${PERFDATA} \
            -o ${DATA}/cc1.fdata || (echo "Could not convert perf-data to bolt for gcc"; exit 1)

        LD_PRELOAD=/usr/lib/libjemalloc.so ${BOLTPATH}/perf2bolt ${GCCPATH}/cc1.org \
            -p ${PERFDATA} \
            -o ${DATA}/cc1plus.fdata || (echo "Could not convert perf-data to bolt for gcc"; exit 1)

        echo "Optimizing cc1 with the generated profile"
        cd ${TOPLEV}
        LD_PRELOAD=/usr/lib/libjemalloc.so ${BOLTPATH}/llvm-bolt ${GCCPATH}/cc1.org \
            --data ${DATA}/cc1.fdata \
            -o ${TOPLEV}/cc1 \
            -reorder-blocks=ext-tsp \
            -reorder-functions=cdsort \
            -split-functions \
            -split-all-cold \
            -split-eh \
            -dyno-stats \
            -icf=1 \
            -use-gnu-stack \
            -plt=hot || (echo "Could not optimize binary for cc1"; exit 1)

        cd ${TOPLEV}
        LD_PRELOAD=/usr/lib/libjemalloc.so ${BOLTPATH}/llvm-bolt ${GCCPATH}/cc1plus.org \
            --data ${DATA}/cc1plus.fdata \
            -o ${TOPLEV}/cc1plus \
            -reorder-blocks=ext-tsp \
            -reorder-functions=cdsort \
            -split-functions \
            -split-all-cold \
            -split-eh \
            -dyno-stats \
            -icf=1 \
            -use-gnu-stack \
            -plt=hot || (echo "Could not optimize binary for cc1plus"; exit 1)
    else
        echo "Merging generated profiles"
        cd ${DATA}/cc1
        ${BOLTPATH}/merge-fdata *.fdata > cc1-combined.fdata
        cd ${DATA}/cc1plus
        ${BOLTPATH}/merge-fdata *.fdata > cc1plus-combined.fdata

        echo "Optimizing cc1 with the generated profile"
        cd ${TOPLEV}
        LD_PRELOAD=/usr/lib/libjemalloc.so ${BOLTPATH}/llvm-bolt ${GCCPATH}/cc1.org \
            --data ${DATA}/cc1/cc1-combined.fdata \
            -o ${TOPLEV}/cc1 \
            -reorder-blocks=ext-tsp \
            -reorder-functions=cdsort \
            -split-functions \
            -split-all-cold \
            -split-eh \
            -dyno-stats \
            -icf=1 \
            -use-gnu-stack \
            -plt=hot || (echo "Could not optimize binary for cc1"; exit 1)

        cd ${TOPLEV}
        LD_PRELOAD=/usr/lib/libjemalloc.so ${BOLTPATH}/llvm-bolt ${GCCPATH}/cc1plus.org \
            --data ${DATA}/cc1plus/cc1plus-combined.fdata \
            -o ${TOPLEV}/cc1plus \
            -reorder-blocks=ext-tsp \
            -reorder-functions=cdsort \
            -split-functions \
            -split-all-cold \
            -split-eh \
            -dyno-stats \
            -icf=1 \
            -use-gnu-stack \
            -plt=hot || (echo "Could not optimize binary for cc1plus"; exit 1)


        echo "mooving bolted binary"
        sudo mv ${TOPLEV}/cc1plus ${GCCPATH}/cc1plus
        sudo mv ${TOPLEV}/cc1 ${GCCPATH}/cc1
        echo "Now you can move the bolted binarys to your ${GCCPATH}"
    fi

fi
