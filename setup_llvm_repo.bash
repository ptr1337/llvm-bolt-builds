#!/bin/bash
export TOPLEV=~/toolchain/llvm
mkdir -p ${TOPLEV}
cd ${TOPLEV}
git clone --depth=1 --branch=release/15.x https://github.com/llvm/llvm-project.git
