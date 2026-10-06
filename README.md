# GPU-Accelerated, dmabuf-based libcamera JNI

This repository provides GPU accelerated frame capture and preprocessing for Raspberry Pi platforms using libcamera and OpenGL. Currently, shaders exist for GPU-accelerated binary HSV thresholding and greyscaling, though others (such as adaptive threshold, like needed for apriltags) will be supported. This code is exposed via JNI for use in [PhotonVision](https://github.com/PhotonVision/photonvision).

## Building

We use CMake for our builds. The build should output both a shared library, `libphotonlibcamera.so`, and a executable for testing. Start by installing dependencies and cloning the repo:

```
sudo apt-get update
sudo apt-get install -y default-jdk libopencv-dev libegl1-mesa-dev libcamera-dev cmake build-essential libdrm-dev libgbm-dev openjdk-25-jdk

git clone https://github.com/PhotonVision/photon-libcamera-gl-driver.git
```

This project requires libcamera >= 0.6.

Build with the following cmake commands:

```
cd photon-libcamera-gl-driver
mkdir cmake_build
cmake -B cmake_build -S .
cmake --build cmake_build
./gradlew build publishToMavenLocal
```

## Arm64 build with sysroot (Docker)

If you are building on an x86_64 host and need an arm64 JNI that links against
libcamera (often >= 0.6) from a target rootfs, run:

```
SYSROOT_DIR=/path/to/target/rootfs \
  MAVEN_LOCAL_REPO=/path/to/m2 \
  tools/build_arm64_jni.sh
```

## Arm64 cross build with a Buildroot toolchain

When the target image is built with Buildroot, cross-compile with the
toolchain and sysroot of that Buildroot output instead of an emulated arm64
container. Buildroot images use Mesa without GLVND, so link EGL/GLESv2
directly:

```
BUILDROOT_HOST_DIR=/path/to/buildroot-output/host \
  MAVEN_LOCAL_REPO=/path/to/m2 \
  CMAKE_EXTRA_ARGS="-DPHOTON_LIBCAMERA_LINK_GLES=ON -DPHOTON_LIBCAMERA_WERROR=OFF" \
  tools/build_arm64_jni.sh
```

`CMAKE_TOOLCHAIN_FILE` can be used instead of `BUILDROOT_HOST_DIR` for other
toolchains. The build host needs a JDK 17, CMake and make; `JAVA_HOME` is
taken from `javac` on `PATH` when unset.

## Running eglinfo

Compile with `g++ -std=c++17 -o eglinfo eglinfo.c headless_opengl.cpp -lEGL -lGLESv2 -lgbm`, and then run with  `./eglinfo`
