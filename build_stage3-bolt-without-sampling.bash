#!/bin/bash

TOPLEV=~/toolchain/llvm
cd ${TOPLEV}

mkdir -p ${TOPLEV}/stage3-without-sampling/intrumentdata || (echo "Could not create stage3-bolt directory"; exit 1)
cd ${TOPLEV}/stage3-without-sampling
CPATH=${TOPLEV}/stage2-prof-use-lto/install/bin
BOLTPATH=${TOPLEV}/llvm-bolt/bin


echo "Instrument clang with llvm-bolt"

${BOLTPATH}/llvm-bolt \
    --instrument \
    --instrumentation-file-append-pid \
    --instrumentation-file=${TOPLEV}/stage3-without-sampling/intrumentdata/clang-16.fdata \
    ${CPATH}/clang-16 \
    -o ${CPATH}/clang-16.inst

echo "mooving instrumented binary"
mv ${CPATH}/clang-16 ${CPATH}/clang-15.org
mv ${CPATH}/clang-16.inst ${CPATH}/clang-15

echo "== Configure Build"
echo "== Build with stage2-prof-use-lto instrumented clang -- $CPATH"

cmake -G Ninja ../llvm-project/llvm \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLVM_ENABLE_PROJECTS="clang" \
    -DLLVM_TARGETS_TO_BUILD="X86" \
    -DCMAKE_AR=${CPATH}/llvm-ar \
    -DCMAKE_C_COMPILER=${CPATH}/clang-16 \
    -DCMAKE_CXX_COMPILER=${CPATH}/clang++ \
    -DLLVM_USE_LINKER=${CPATH}/ld.lld \
    -DCMAKE_RANLIB=${CPATH}/llvm-ranlib \
    -DCMAKE_INSTALL_PREFIX=${TOPLEV}/stage3-without-sampling/install

echo "== Start Training Build"
ninja & read -t 240 || kill $!

echo "Merging generated profiles"
cd ${TOPLEV}/stage3-without-sampling/intrumentdata
LD_PRELOAD=/usr/lib/libjemalloc.so ${BOLTPATH}/merge-fdata *.fdata > combined.fdata
echo "Optimizing Clang with the generated profile"

LD_PRELOAD=/usr/lib/libjemalloc.so ${BOLTPATH}/llvm-bolt ${CPATH}/clang-16.org \
    --data combined.fdata \
    -o ${CPATH}/clang-16 \
    -relocs \
    -split-functions \
    -split-all-cold \
    -icf=1 \
    -lite=1 \
    -split-eh \
    -use-gnu-stack \
    -jump-tables=move \
    -dyno-stats \
    -reorder-functions=hfsort \
    -reorder-blocks=ext-tsp \
    -plt=all || (echo "Could not optimize binary for clang"; exit 1)

echo "You can now use the compiler with export PATH=${CPATH}:${PATH}"
