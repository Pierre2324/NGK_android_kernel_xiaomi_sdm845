#!/bin/sh

# Some general variables
PHONE="beryllium"
ARCH="arm64"
SUBARCH="arm64"
DEFCONFIG=vendor/nogravity-${PHONE}_defconfig
COMPILER=clang
LINKER="lld"
COMPILERDIR="/media/pierre/Expension/Android/PocoX3Pro/Kernels/Proton-Clang"

# Cleanup output
rm -rf out/outputs/${PHONE}/*

# Outputs
mkdir out/outputs
mkdir out/outputs/${PHONE}
mkdir out/outputs/${PHONE}/9.1.24
mkdir out/outputs/${PHONE}/10.3.7

# Export shits
export KBUILD_BUILD_USER=Pierre2324
export KBUILD_BUILD_HOST=G7-7588

# Speed up build process
MAKE="./makeparallel"

# Basic build function
BUILD_START=$(date +"%s")
blue='\033[0;34m'
cyan='\033[0;36m'
yellow='\033[0;33m'
red='\033[0;31m'
nocol='\033[0m'

Build () {
PATH="${COMPILERDIR}/bin:${PATH}" \
make -j$(nproc --all) O=out \
ARCH=${ARCH} \
LLVM=1 \
LLVM_IAS=1 \
CC=${COMPILER} \
CROSS_COMPILE=${COMPILERDIR}/bin/aarch64-linux-gnu- \
CROSS_COMPILE_COMPAT=${COMPILERDIR}/bin/arm-linux-gnueabi- \
LD_LIBRARY_PATH=${COMPILERDIR}/lib \
Image.gz-dtb
}

Build_lld () {
PATH="${COMPILERDIR}/bin:${PATH}" \
make -j$(nproc --all) O=out \
ARCH=${ARCH} \
LLVM=1 \
LLVM_IAS=1 \
CC=${COMPILER} \
CROSS_COMPILE=${COMPILERDIR}/bin/aarch64-linux-gnu- \
CROSS_COMPILE_COMPAT=${COMPILERDIR}/bin/arm-linux-gnueabi- \
LD=ld.${LINKER} \
AR=llvm-ar \
NM=llvm-nm \
OBJCOPY=llvm-objcopy \
OBJDUMP=llvm-objdump \
STRIP=llvm-strip \
ld-name=${LINKER} \
KBUILD_COMPILER_STRING="Proton Clang" \
Image.gz-dtb
}

# Make defconfig

make O=out ARCH=${ARCH} ${DEFCONFIG}
if [ $? -ne 0 ]
then
    echo "Build failed"
else
    echo "Made ${DEFCONFIG}"
fi

make O=out ARCH=${ARCH} ${DEFCONFIG}
if [ $? -ne 0 ]
then
    echo "Build failed"
else
    echo "Made ${DEFCONFIG}"
fi

# Build starts here
if [ -z ${LINKER} ]
then
    #Start with 9.1.24
    cp firmware/touch_fw_variant/9.1.24/* firmware/
    Build
else
    Build_lld
fi

if [ $? -ne 0 ]
then
    echo "Build failed"
    rm -rf out/outputs/${PHONE}/*
else
    echo "Build succesful"
    cp out/arch/arm64/boot/Image.gz-dtb out/outputs/${PHONE}/9.1.24/Image.gz-dtb
    
    #10.3.7
    cp firmware/touch_fw_variant/10.3.7/* firmware/
    Build
    if [ $? -ne 0 ]
    then
        echo "Build failed"
        rm -rf out/outputs/${PHONE}/10.3.7/*
    else
        echo "Build succesful"
        cp out/arch/arm64/boot/Image.gz-dtb out/outputs/${PHONE}/10.3.7/Image.gz-dtb
    fi
fi


BUILD_END=$(date +"%s")
DIFF=$(($BUILD_END - $BUILD_START))
echo -e "$yellow Build completed in $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds.$nocol"