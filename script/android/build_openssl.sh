#!/bin/bash
export ROOT_PATH=`pwd`
export REPO_PATH=${ROOT_PATH}/repos
echo "ROOT_PATH: ${ROOT_PATH}"
echo "REPO_PATH: ${REPO_PATH}"

if [ "${ANDROID_NDK}" == "" ]; then
  echo "ANDROID_NDK not set"
  exit 1;
fi

export OPENSSL_REPO_PATH=${REPO_PATH}/openssl-1.1.1s
export DIST_PATH=${ROOT_PATH}/dist

cd ${OPENSSL_REPO_PATH}

NDK_PATH=${ANDROID_NDK} # tag1
# macOS $NDK_PATH/toolchains/llvm/prebuilt/
HOST_PLATFORM=darwin-x86_64  #tag1
# minSdkVersion
API=21

TOOLCHAINS="$NDK_PATH/toolchains/llvm/prebuilt/$HOST_PLATFORM"
SYSROOT="$NDK_PATH/toolchains/llvm/prebuilt/$HOST_PLATFORM/sysroot"

CFLAG="-Os -fPIC -DANDROID "
LDFLAG="-lc -lm -ldl -llog "

PREFIX=${DIST_PATH}/android
CONFIG_LOG_PATH=${PREFIX}/log

COMMON_OPTIONS=
CONFIGURATION=

build() {
  APP_ABI=$1
  echo "======== > Start build $APP_ABI"
  case ${APP_ABI} in
  armeabi-v7a)
    ARCH="arm"
    CPU="armv7-a"
    MARCH="armv7-a"
    TARGET=armv7a-linux-androideabi
    CC="$TOOLCHAINS/bin/$TARGET$API-clang"
    CXX="$TOOLCHAINS/bin/$TARGET$API-clang++"
    CROSS_PREFIX="$TOOLCHAINS/bin/$TARGET$API-"
    EXTRA_CFLAGS="$CFLAG -mfloat-abi=softfp -mfpu=vfp -marm -march=$MARCH "
    EXTRA_LDFLAGS="$LDFLAG"
    EXTRA_OPTIONS="--enable-neon --cpu=$CPU "
    OPENSSL_OS=android-arm
    ;;
  arm64-v8a)
    ARCH="aarch64"
    TARGET=$ARCH-linux-android
    CC="$TOOLCHAINS/bin/$TARGET$API-clang"
    CXX="$TOOLCHAINS/bin/$TARGET$API-clang++"
    CROSS_PREFIX="$TOOLCHAINS/bin/$TARGET-"
    EXTRA_CFLAGS="$CFLAG"
    EXTRA_LDFLAGS="$LDFLAG"
    EXTRA_OPTIONS="--enable-neon"
    OPENSSL_OS=android-arm64
    ;;
  x86)
    ARCH="x86"
    CPU="i686"
    MARCH="i686"
    TARGET=i686-linux-android
    CC="$TOOLCHAINS/bin/$TARGET$API-clang"
    CXX="$TOOLCHAINS/bin/$TARGET$API-clang++"
    CROSS_PREFIX="$TOOLCHAINS/bin/$TARGET-"
    #EXTRA_CFLAGS="$CFLAG -march=$MARCH -mtune=intel -mssse3 -mfpmath=sse -m32"
    EXTRA_CFLAGS="$CFLAG -march=$MARCH  -mssse3 -mfpmath=sse -m32"
    EXTRA_LDFLAGS="$LDFLAG"
    EXTRA_OPTIONS="--disable-asm"
    OPENSSL_OS=android-x86
    ;;
  x86_64)
    ARCH="x86_64"
    CPU="x86-64"
    MARCH="x86_64"
    TARGET=$ARCH-linux-android
    CC="$TOOLCHAINS/bin/$TARGET$API-clang"
    CXX="$TOOLCHAINS/bin/$TARGET$API-clang++"
    CROSS_PREFIX="$TOOLCHAINS/bin/$TARGET-"
    #EXTRA_CFLAGS="$CFLAG -march=$CPU -mtune=intel -msse4.2 -mpopcnt -m64"
    EXTRA_CFLAGS="$CFLAG -march=$CPU -msse4.2 -mpopcnt -m64"
    EXTRA_LDFLAGS="$LDFLAG"
    EXTRA_OPTIONS="--disable-asm"
    OPENSSL_OS=android-x86_64
    ;;
  esac

  echo "-------- > Start clean workspace"
  make clean

  echo "-------- > Start build configuration"

  export PATH=$TOOLCHAINS/bin:$PATH
  export CC=$CC
  export CXX=$CXX
  export RANLIB="$TOOLCHAINS/bin/llvm-ranlib"
  export AR="$TOOLCHAINS/bin/llvm-ar"
  export ANDROID_API=$API

  echo "-------- > Start config OPENSSL $OPENSSL_OS"


  #./Configure $OPENSSL_OS --prefix=$PREFIX/$APP_ABI -D__ANDROID_API__=$API no-shared
  ./Configure $OPENSSL_OS --prefix=$PREFIX/$APP_ABI -U__ANDROID_API__ -D__ANDROID_API__=$API no-shared

  echo "-------- > Start make $APP_ABI with -j16"
  make -j16
  echo "++++++++ > make and install $APP_ABI complete."

  echo "-------- > Start install $APP_ABI"
  make install
  echo "++++++++ > make and install $APP_ABI complete."

}

build_all() {
  build "armeabi-v7a"
  build "arm64-v8a"
  build "x86"
  build "x86_64"
}

echo "-------- Start --------"
build_all
echo "-------- End --------"