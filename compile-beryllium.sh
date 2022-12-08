#!/bin/sh

# Many parts of this script were taken from @REIGNZ, @idkwhoiam322 and @raphielscape . Huge thanks to them.

# Some general variables
PHONE="beryllium"
ARCH="arm64"
SUBARCH="arm64"
DEFCONFIG=nogravity_defconfig
#DEFCONFIG=beryllium_defconfig
COMPILER=clang
LINKER=""
COMPILERDIR="/media/pierre/Expension/Android/PocophoneF1/Kernels/Proton-Clang"

# Outputs
mkdir out/outputs
mkdir out/outputs/${PHONE}
mkdir out/outputs/${PHONE}/9.1.24-SE
mkdir out/outputs/${PHONE}/9.1.24-NSE
mkdir out/outputs/${PHONE}/10.3.7-SE
mkdir out/outputs/${PHONE}/10.3.7-NSE

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
CC=${COMPILER} \
CROSS_COMPILE=${COMPILERDIR}/bin/aarch64-linux-gnu- \
CROSS_COMPILE_ARM32=${COMPILERDIR}/bin/arm-linux-gnueabi- \
LD_LIBRARY_PATH=${COMPILERDIR}/lib
}

Build_lld () {
PATH="${COMPILERDIR}/bin:${PATH}" \
make -j$(nproc --all) O=out \
ARCH=${ARCH} \
CC=${COMPILER} \
CROSS_COMPILE=${COMPILERDIR}/bin/aarch64-linux-gnu- \
CROSS_COMPILE_ARM32=${COMPILERDIR}/bin/arm-linux-gnueabi- \
LD=ld.${LINKER} \
AR=llvm-ar \
NM=llvm-nm \
OBJCOPY=llvm-objcopy \
OBJDUMP=llvm-objdump \
STRIP=llvm-strip \
ld-name=${LINKER} \
KBUILD_COMPILER_STRING="Proton Clang"
}

# Make defconfig

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
    #Start with 9.1.24-SE
    cp firmware/touch_fw_variant/9.1.24/* firmware/
    cp arch/arm64/boot/dts/qcom/SE_NSE/SE/* arch/arm64/boot/dts/qcom/
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
    cp out/arch/arm64/boot/Image.gz-dtb out/outputs/${PHONE}/9.1.24-SE/Image.gz-dtb
    
    #9.1.24-NSE
    cp arch/arm64/boot/dts/qcom/SE_NSE/NSE/* arch/arm64/boot/dts/qcom/
    Build
    if [ $? -ne 0 ]
    then
        echo "Build failed"
        rm -rf out/outputs/${PHONE}/9.1.24-NSE/*
    else
        echo "Build succesful"
        cp out/arch/arm64/boot/Image.gz-dtb out/outputs/${PHONE}/9.1.24-NSE/Image.gz-dtb

        #10.3.7-SE
        cp firmware/touch_fw_variant/10.3.7/* firmware/
        cp arch/arm64/boot/dts/qcom/SE_NSE/SE/* arch/arm64/boot/dts/qcom/
        Build
        if [ $? -ne 0 ]
        then
            echo "Build failed"
            rm -rf out/outputs/${PHONE}/10.3.7-SE/*
        else
            echo "Build succesful"
            cp out/arch/arm64/boot/Image.gz-dtb out/outputs/${PHONE}/10.3.7-SE/Image.gz-dtb

            #10.3.7-NSE
            cp arch/arm64/boot/dts/qcom/SE_NSE/NSE/* arch/arm64/boot/dts/qcom/
            Build
            if [ $? -ne 0 ]
            then
                echo "Build failed"
                rm -rf out/outputs/${PHONE}/10.3.7-NSE/*
            else
                echo "Build succesful"
                cp out/arch/arm64/boot/Image.gz-dtb out/outputs/${PHONE}/10.3.7-NSE/Image.gz-dtb
            fi
        fi
    fi
fi

BUILD_END=$(date +"%s")
DIFF=$(($BUILD_END - $BUILD_START))
echo -e "$yellow Build completed in $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds.$nocol"