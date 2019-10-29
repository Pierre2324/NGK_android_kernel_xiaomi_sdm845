make O=out ARCH=arm64 nogravity_defconfig

PATH="/media/pierre/Expension/Android/PocophoneF1/Kernels/clang-linux-x86/clang-stable/bin:/media/pierre/Expension/Android/PocophoneF1/Kernels/aarch64-maestroTC/bin:${PATH}" \
make -j$(nproc --all) O=out \
                      ARCH=arm64 \
                      CC=clang \
                      CLANG_TRIPLE=aarch64-maestro-linux-gnu- \
                      CROSS_COMPILE=aarch64-linux-android-