#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Cross-compile with a CMake toolchain file instead of an emulated arm64
# container. BUILDROOT_HOST_DIR is a Buildroot output's host/ directory; its
# toolchain file already points at the matching sysroot.
toolchain_file="${CMAKE_TOOLCHAIN_FILE:-}"
if [ -z "${toolchain_file}" ] && [ -n "${BUILDROOT_HOST_DIR:-}" ]; then
  toolchain_file="${BUILDROOT_HOST_DIR}/share/buildroot/toolchainfile.cmake"
fi

sysroot_dir="${SYSROOT_DIR:-}"
if [ -n "${toolchain_file}" ]; then
  if [ ! -f "${toolchain_file}" ]; then
    echo "CMake toolchain file not found: ${toolchain_file}" 1>&2
    exit 1
  fi
  toolchain_file="$(realpath "${toolchain_file}")"
elif [ -z "${sysroot_dir}" ]; then
  echo "SYSROOT_DIR is required (path to the target rootfs or sysroot)." 1>&2
  exit 1
fi
if [ -n "${sysroot_dir}" ]; then
  sysroot_dir="$(realpath "${sysroot_dir}")"
fi

docker_base_image="${DOCKER_BASE_IMAGE:-debian:bookworm}"
docker_image="${DOCKER_IMAGE:-photon-libcamera-gl-driver-arm64-jni:bookworm}"
dockerfile="${DOCKERFILE:-${repo_root}/tools/docker/arm64-jni.Dockerfile}"
docker_platform="${DOCKER_PLATFORM:-linux/arm64}"
build_docker_image="${BUILD_DOCKER_IMAGE:-1}"
maven_local_repo="${MAVEN_LOCAL_REPO:-${repo_root}/.m2-arm64}"
cmake_extra_args="${CMAKE_EXTRA_ARGS:-}"
gradle_extra_args="${GRADLE_EXTRA_ARGS:-}"
clean_build="${CLEAN_BUILD:-0}"
# SKIP_GRADLE=1 stops after the CMake build (cmake_build/libphotonlibcamera.so),
# for consumers that only need the shared library, e.g. to swap it into a
# released PhotonVision jar. The v2026 Gradle wrapper does not run on JDK 25.
skip_gradle="${SKIP_GRADLE:-0}"
sysroot_mode="${SYSROOT_MODE:-libcamera}"
use_docker="${USE_DOCKER:-1}"
if [ -n "${toolchain_file}" ]; then
  # A toolchain file means a native cross build; never wrap it in Docker.
  use_docker=0
fi

if [ "${clean_build}" = "1" ]; then
  rm -rf "${repo_root}/cmake_build" || true
fi

mkdir -p "${maven_local_repo}"

if [ "${use_docker}" != "1" ]; then
  export DEBIAN_FRONTEND=noninteractive
  if [ -z "${toolchain_file}" ]; then
    export PKG_CONFIG_SYSROOT_DIR="${sysroot_dir}"
    export PKG_CONFIG_PATH="${sysroot_dir}/usr/lib/aarch64-linux-gnu/pkgconfig:${sysroot_dir}/usr/lib/pkgconfig:${sysroot_dir}/usr/share/pkgconfig:${sysroot_dir}/usr/local/lib/aarch64-linux-gnu/pkgconfig:${sysroot_dir}/usr/local/lib/pkgconfig:/usr/lib/aarch64-linux-gnu/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig"
  fi
  if [ -z "${JAVA_HOME:-}" ]; then
    if command -v javac >/dev/null 2>&1; then
      JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")"
    else
      arch="$(dpkg --print-architecture 2>/dev/null || true)"
      if [ "${arch}" = "amd64" ]; then
        JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"
      else
        JAVA_HOME="/usr/lib/jvm/java-17-openjdk-arm64"
      fi
    fi
  fi
  export JAVA_HOME
  # Trust the checkout for the gradle versioning helper without editing the
  # user's global git config.
  export GIT_CONFIG_COUNT=1
  export GIT_CONFIG_KEY_0=safe.directory
  export GIT_CONFIG_VALUE_0="${repo_root}"

  build_dir="${repo_root}/cmake_build"
  cmake_args=(
    -B "${build_dir}"
    -S "${repo_root}"
    -DOpenGL_GL_PREFERENCE=GLVND
    -DBUILD_CAMERA_MEME=OFF
  )
  if [ -n "${toolchain_file}" ]; then
    # The toolchain file restricts header lookups to the target sysroot, so
    # FindJNI cannot find the JNI headers of the build JDK on its own, and
    # Buildroot's compiler wrapper rejects -I paths under /usr. jni.h and
    # jni_md.h are architecture independent on Linux, so copy them into the
    # build tree and point FindJNI there. JAVA_JVM_LIBRARY only satisfies
    # FindJNI's JVM component; the library does not link against libjvm.
    jni_include="${build_dir}/jni-include"
    mkdir -p "${jni_include}/linux"
    cp "${JAVA_HOME}/include/jni.h" "${jni_include}/"
    cp "${JAVA_HOME}/include/linux/jni_md.h" "${jni_include}/linux/"
    cmake_args+=(
      -DCMAKE_TOOLCHAIN_FILE="${toolchain_file}"
      -DJAVA_HOME="${JAVA_HOME}"
      -DJAVA_INCLUDE_PATH="${jni_include}"
      -DJAVA_INCLUDE_PATH2="${jni_include}/linux"
      -DJAVA_AWT_INCLUDE_PATH="${jni_include}"
      -DJAVA_JVM_LIBRARY="${JAVA_HOME}/lib/server/libjvm.so"
      # Debian and Ubuntu link with --as-needed by default; Buildroot does
      # not. Without it the library records every OpenCV module as NEEDED,
      # and PhotonVision only loads the ones it uses.
      -DCMAKE_SHARED_LINKER_FLAGS="-Wl,--as-needed"
    )
  elif [ "${sysroot_mode}" = "full" ]; then
    cmake_args+=(
      -DCMAKE_SYSROOT="${sysroot_dir}"
      -DCMAKE_FIND_ROOT_PATH="${sysroot_dir}"
      -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY
      -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY
      -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY
      -DCMAKE_PREFIX_PATH="${sysroot_dir}/usr;${sysroot_dir}/usr/local"
    )
  else
    cmake_args+=(
      -DCMAKE_LIBRARY_PATH="${sysroot_dir}/usr/lib/aarch64-linux-gnu:${sysroot_dir}/usr/local/lib/aarch64-linux-gnu"
      -DCMAKE_INCLUDE_PATH="${sysroot_dir}/usr/include:${sysroot_dir}/usr/local/include"
    )
  fi
  cmake "${cmake_args[@]}" ${cmake_extra_args}
  cmake --build "${build_dir}" -j"$(nproc)"
  if [ "${skip_gradle}" = "1" ]; then
    exit 0
  fi

  cd "${repo_root}"
  ./gradlew --no-daemon \
    -Dmaven.repo.local="${maven_local_repo}" \
    build publishToMavenLocal \
    -PArchOverride=linuxarm64 \
    ${gradle_extra_args}
  exit 0
fi

if [ "${build_docker_image}" = "1" ]; then
  docker build \
    --platform="${docker_platform}" \
    --build-arg "BASE_IMAGE=${docker_base_image}" \
    -f "${dockerfile}" \
    -t "${docker_image}" \
    "${repo_root}"
fi

docker run --rm --platform="${docker_platform}" \
  --user "$(id -u):$(id -g)" \
  -v "${repo_root}:/work" \
  -v "${sysroot_dir}:/sysroot:ro" \
  -v "${maven_local_repo}:/work/.m2-arm64" \
  -e HOME=/tmp \
  -e "SYSROOT_MODE=${sysroot_mode}" \
  -e "CMAKE_EXTRA_ARGS=${cmake_extra_args}" \
  -e "GRADLE_EXTRA_ARGS=${gradle_extra_args}" \
  "${docker_image}"
