#!/bin/bash
export TOPLEV=~/toolchain/llvm
mkdir -p ${TOPLEV}
cd ${TOPLEV}
git clone https://github.com/llvm/llvm-project.git
