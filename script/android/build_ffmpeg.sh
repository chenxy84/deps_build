#!/bin/bash
export ROOT_PATH=`pwd`
export REPO_PATH=${ROOT_PATH}/repos
echo "ROOT_PATH: ${ROOT_PATH}"
echo "REPO_PATH: ${REPO_PATH}"

if [ "${ANDROID_NDK}" == "" ]; then
	echo "ANDROID_NDK not set"
	exit 1;
fi

export FFMPEG_REPO_PATH=${REPO_PATH}/ffmpeg-5.1.2
export DIST_PATH=${ROOT_PATH}/dist

cd ${FFMPEG_REPO_PATH}

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
    EXTRA_CFLAGS="$CFLAG --arch=x86 -march=$MARCH  -mssse3 -mfpmath=sse -m32"
    EXTRA_LDFLAGS="$LDFLAG"
    EXTRA_OPTIONS="--cpu=$CPU --disable-asm"
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
    EXTRA_CFLAGS="$CFLAG --arch=x86_64 -march=$CPU -msse4.2 -mpopcnt -m64"
    EXTRA_LDFLAGS="$LDFLAG"
    EXTRA_OPTIONS="--cpu=$CPU --disable-asm"
    ;;
  esac

  echo "-------- > Start clean workspace"
  make clean

  echo "-------- > Start build configuration"
  CONFIGURATION="$COMMON_OPTIONS"
  CONFIGURATION="$CONFIGURATION --logfile=$CONFIG_LOG_PATH/config_$APP_ABI.log"
  CONFIGURATION="$CONFIGURATION --prefix=$PREFIX"
  CONFIGURATION="$CONFIGURATION --libdir=$PREFIX/libs/$APP_ABI"
  CONFIGURATION="$CONFIGURATION --incdir=$PREFIX/includes/$APP_ABI"
  CONFIGURATION="$CONFIGURATION --pkgconfigdir=$PREFIX/pkgconfig/$APP_ABI"
  CONFIGURATION="$CONFIGURATION --pkg-config=pkg-config"
  CONFIGURATION="$CONFIGURATION --cross-prefix=$CROSS_PREFIX"
  CONFIGURATION="$CONFIGURATION --arch=$ARCH"
  CONFIGURATION="$CONFIGURATION --sysroot=$SYSROOT"
  CONFIGURATION="$CONFIGURATION --cc=$CC"
  CONFIGURATION="$CONFIGURATION --cxx=$CXX"
  CONFIGURATION="$CONFIGURATION --as=$CC"
  CONFIGURATION="$CONFIGURATION --ld=$CC"
  CONFIGURATION="$CONFIGURATION --enable-pic"
  #tools
  CONFIGURATION="$CONFIGURATION --ranlib=$TOOLCHAINS/bin/llvm-ranlib"
  CONFIGURATION="$CONFIGURATION --ar=$TOOLCHAINS/bin/llvm-ar"
  CONFIGURATION="$CONFIGURATION --nm=$TOOLCHAINS/bin/llvm-nm"
  CONFIGURATION="$CONFIGURATION --strip=$TOOLCHAINS/bin/llvm-strip"
  CONFIGURATION="$CONFIGURATION $EXTRA_OPTIONS"

  echo "-------- > Start config makefile with $CONFIGURATION --extra-cflags=${EXTRA_CFLAGS} --extra-ldflags=${EXTRA_LDFLAGS}"
  ./configure ${CONFIGURATION} \
  --extra-cflags="$EXTRA_CFLAGS" \
  --extra-ldflags="$EXTRA_LDFLAGS"

  echo "-------- > Start make $APP_ABI with -j16"
  make -j16

  echo "-------- > Start install $APP_ABI"
  make install
  echo "++++++++ > make and install $APP_ABI complete."

  echo "-------- > Generate libffmpeg.so"
  pushd $PREFIX/libs/$APP_ABI
  $CC $CFLAGS -shared -o libffmpeg.so -Wl,--whole-archive -Wl,-Bsymbolic \
  libavcodec.a libavformat.a libswresample.a libavfilter.a libavutil.a libswscale.a -Wl,--no-whole-archive

  popd
  echo "++++++++ > Generate $APP_ABI/libffmpeg.so complete."

}

build_all() {
  #gpl support
  #COMMON_OPTIONS="$COMMON_OPTIONS --enable-gpl"
  #target android
  COMMON_OPTIONS="$COMMON_OPTIONS --target-os=android"
  
  #COMMON_OPTIONS="$COMMON_OPTIONS --disable-static"
  #COMMON_OPTIONS="$COMMON_OPTIONS --enable-shared"
  
  
  COMMON_OPTIONS="$COMMON_OPTIONS --enable-cross-compile"
  COMMON_OPTIONS="$COMMON_OPTIONS --enable-optimizations"

  #debug option
  COMMON_OPTIONS="$COMMON_OPTIONS --disable-debug"

  #disable
  COMMON_OPTIONS="$COMMON_OPTIONS --disable-doc"

  COMMON_OPTIONS="$COMMON_OPTIONS --disable-programs"
  COMMON_OPTIONS="$COMMON_OPTIONS --disable-vulkan"

  COMMON_OPTIONS="$COMMON_OPTIONS --disable-avdevice"
  COMMON_OPTIONS="$COMMON_OPTIONS --disable-postproc"

  COMMON_OPTIONS="$COMMON_OPTIONS --disable-everything"

  COMMON_OPTIONS="$COMMON_OPTIONS --enable-decoder=aac"
  COMMON_OPTIONS="$COMMON_OPTIONS --enable-decoder=mp3"
  COMMON_OPTIONS="$COMMON_OPTIONS --enable-decoder=h264"
  COMMON_OPTIONS="$COMMON_OPTIONS --enable-decoder=hevc"
  COMMON_OPTIONS="$COMMON_OPTIONS --enable-decoder=flv"

  COMMON_OPTIONS="$COMMON_OPTIONS --enable-demuxer=aac"
  COMMON_OPTIONS="$COMMON_OPTIONS --enable-demuxer=mp3"
  COMMON_OPTIONS="$COMMON_OPTIONS --enable-demuxer=mov"
  COMMON_OPTIONS="$COMMON_OPTIONS --enable-demuxer=hevc"
  COMMON_OPTIONS="$COMMON_OPTIONS --enable-demuxer=hls"
  COMMON_OPTIONS="$COMMON_OPTIONS --enable-demuxer=mpegts"
  COMMON_OPTIONS="$COMMON_OPTIONS --enable-demuxer=flv"

  COMMON_OPTIONS="$COMMON_OPTIONS --enable-parser=aac"
  COMMON_OPTIONS="$COMMON_OPTIONS --enable-parser=h264"
  COMMON_OPTIONS="$COMMON_OPTIONS --enable-parser=mpegaudio"
  COMMON_OPTIONS="$COMMON_OPTIONS --enable-parser=hevc"

  COMMON_OPTIONS="$COMMON_OPTIONS --enable-protocol=file"
  COMMON_OPTIONS="$COMMON_OPTIONS --enable-protocol=hls"
  COMMON_OPTIONS="$COMMON_OPTIONS --enable-protocol=http"
  COMMON_OPTIONS="$COMMON_OPTIONS --enable-protocol=https"
  COMMON_OPTIONS="$COMMON_OPTIONS --enable-protocol=rtmp"
  COMMON_OPTIONS="$COMMON_OPTIONS --enable-protocol=tcp"
  COMMON_OPTIONS="$COMMON_OPTIONS --enable-protocol=tls"

  #COMMON_OPTIONS="$COMMON_OPTIONS --enable-openssl"

  echo "COMMON_OPTIONS=$COMMON_OPTIONS"
  echo "PREFIX=$PREFIX"
  echo "CONFIG_LOG_PATH=$CONFIG_LOG_PATH"
  mkdir -p ${CONFIG_LOG_PATH}
  # build "armeabi-v7a"
  build "arm64-v8a"
  # build "x86"
  # build "x86_64"
}

echo "-------- Start --------"
build_all
echo "-------- End --------"

