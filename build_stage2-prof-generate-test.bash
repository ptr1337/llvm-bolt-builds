#!/bin/bash
jobs="$(echo $(( $(nproc) * 3/4 )) | cut -d '.' -f1)"
BASE_DIR=$(pwd)
CPATH="$(pwd)/stage1/install/bin"

mkdir -p stage2-prof-generate-test || (echo "Could not create stage2-prof-generate directory"; exit 1)
cd stage2-prof-generate-test

echo "== Configure Build"
echo "== Build with stage1-tools -- $CPATH"

cmake 	-G Ninja \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX="$(pwd)/install" \
	-DLLVM_BINUTILS_INCDIR=/usr/include \
	-DLLVM_HOST_TRIPLE="x86_64-pc-linux-gnu" \
	-DLLVM_BUILD_RUNTIME=ON \
	-DLLVM_BUILD_EXTERNAL_COMPILER_RT=ON \
	-DLLVM_BUILD_LLVM_DYLIB=ON \
	-DLLVM_LINK_LLVM_DYLIB=ON \
	-DCLANG_LINK_CLANG_DYLIB=ON \
	-DLLVM_INSTALL_UTILS=ON \
	-DLLVM_ENABLE_RTTI=ON \
	-DLLVM_ENABLE_FFI=ON \
	-DLLVM_ENABLE_LTO=Thin \
	-DLLVM_ENABLE_PROJECTS="clang;clang-tools-extra;compiler-rt;lld;lldb;mlir;openmp;polly;pstl" \
	-DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi" \
	-DCLANG_LINK_CLANG_DYLIB=ON \
	-DLLDB_USE_SYSTEM_SIX=1 \
	-DLLVM_BUILD_DOCS=OFF \
	-DLLVM_USE_LINKER=mold \
	-DLLVM_BUILD_TESTS=OFF \
	-DLLVM_BUILD_INSTRUMENTED=IR \
	-DLLVM_BUILD_RUNTIME=OFF \
	-DLLVM_VP_COUNTERS_PER_SITE=6 \
	-DCMAKE_EXE_LINKER_FLAGS="-Wl,--as-needed -Wl,--build-id=sha1 -Wl,--emit-relocs" \
	-DENABLE_LINKER_BUILD_ID=ON \
	-DLLVM_ENABLE_PROJECTS="clang;lld;compiler-rt;polly" \
	-DLLVM_PARALLEL_COMPILE_JOBS="$(jobs)" \
	-DLLVM_PARALLEL_LINK_JOBS="$(jobs)" \
	-DLIBOMP_INSTALL_ALIASES=OFF \
	-DLLVM_INSTALL_TOOLCHAIN_ONLY=OFF \
	-DPOLLY_ENABLE_GPGPU_CODEGEN=ON \
	-DCMAKE_INSTALL_PREFIX=${BASE_DIR}/stage2-prof-generate-test/install \
	-DCLANG_DEFAULT_PIE_ON_LINUX=ON \
	../llvm-project/llvm || (echo "Could not configure project!"; exit 1)

echo
echo "== Start Build"
ninja || (echo "Could not build project!"; exit 1)

echo
echo "== Install to $(pwd)/install"
ninja install || (echo "Could not install project!"; exit 1)