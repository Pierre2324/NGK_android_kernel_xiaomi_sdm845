make O=out ARCH=arm64 nogravity_defconfig

PATH="/media/pierre/Expension/Android/PocophoneF1/Kernels/Proton-Clang/bin:/media/pierre/Expension/Android/PocophoneF1/Kernels/Proton-Clang/bin:/usr/lib/ccache:${PATH}" \
make -j$(nproc --all) O=out \
                      ARCH=arm64 \
                      CC="ccache clang" \
                      CLANG_TRIPLE=aarch64-linux-gnu- \
                      CROSS_COMPILE=aarch64-linux-android-