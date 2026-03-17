{ lib
, stdenv
, qtSvgSource
, qtVersion
, qt6Linux       # Linux Qt (host tools: moc, rcc, uic)
, qt6Macos       # Installed qtbase for macOS to build against
, targetArch     # "aarch64" or "x86_64"
, xcode          # darwin.xcode_12_2
, llvmPackages   # LLVM toolchain

# Build tools (native, run on build machine)
, cmake
, ninja
, perl
, python3
, pkg-config
, which
}:

let
  targetTriple = "${targetArch}-apple-darwin";
  sdkRoot = "${xcode}/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk";
  libcxxInclude = "${xcode}/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/include/c++/v1";
  macosVersion = "11.0";
  clangTarget = "${targetArch}-apple-macos${macosVersion}";
  clangBuiltinInclude = "${llvmPackages.clang-unwrapped.lib}/lib/clang/18/include";
in

stdenv.mkDerivation rec {
  pname = "qt6-svg-static-macos-${targetArch}";
  version = qtVersion;

  src = qtSvgSource;

  sourceRoot = "source";

  unpackPhase = ''
    runHook preUnpack
    cp -r $src source
    chmod -R u+w source
    runHook postUnpack
  '';

  nativeBuildInputs = [
    cmake
    ninja
    perl
    python3
    pkg-config
    which
    llvmPackages.clang
    llvmPackages.lld
    llvmPackages.llvm
    llvmPackages.bintools
  ];

  depsBuildBuild = [
    qt6Linux
    xcode
  ];

  cmakeFlags = [
    "-DCMAKE_PREFIX_PATH=${qt6Macos}"

    "-DQT_BUILD_EXAMPLES=OFF"
    "-DQT_BUILD_TESTS=OFF"

    # Cross-compilation settings
    "-DCMAKE_SYSTEM_NAME=Darwin"
    "-DCMAKE_SYSTEM_PROCESSOR=${targetArch}"
    "-DCMAKE_CROSSCOMPILING=ON"
    "-DCMAKE_OSX_DEPLOYMENT_TARGET=${macosVersion}"
    "-DCMAKE_OSX_SYSROOT=${sdkRoot}"

    "-DCMAKE_FIND_ROOT_PATH=${sdkRoot};${qt6Macos}"
    "-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER"
    "-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY"
    "-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY"

    # Host Qt tools path
    "-DQT_HOST_PATH=${qt6Linux}"
    "-DQT_HOST_PATH_CMAKE_DIR=${qt6Linux}/lib/cmake"

    # Bypass Apple SDK checks
    "-DQT_INTERNAL_APPLE_SDK_VERSION:STRING=${macosVersion}"
    "-DQT_INTERNAL_XCODE_VERSION:STRING=12.2"
    "-DQT_NO_APPLE_SDK_MIN_VERSION_CHECK=ON"
    "-DQT_NO_APPLE_SDK_MAX_VERSION_CHECK=ON"
    "-DQT_NO_XCODE_MIN_VERSION_CHECK=ON"
    "-DQT_FORCE_WARN_APPLE_SDK_AND_XCODE_CHECK=ON"
    "-DCMAKE_XCODE_ATTRIBUTE_DEVELOPMENT_TEAM="

    "-DCMAKE_BUILD_TYPE=Release"
    "-GNinja"
  ];

  # Reuse the same cross-compilation wrapper setup from macos.nix
  preConfigure = ''
    export SDKROOT="${sdkRoot}"
    export PATH="${qt6Linux}/bin:$PATH"

    SDK_FRAMEWORKS="${sdkRoot}/System/Library/Frameworks"
    LIBCXX_INCLUDE="${libcxxInclude}"

    mkdir -p $TMPDIR/cross-wrapper

    # Create clang wrapper
    cat > $TMPDIR/cross-wrapper/clang << 'WRAPPER'
#!/bin/sh
args=""
skip_next=0
for arg in "$@"; do
    if [ $skip_next -eq 1 ]; then
        skip_next=0
        continue
    fi
    case "$arg" in
        --target=*) continue ;;
        -target=*) continue ;;
        --target) skip_next=1; continue ;;
        -target) skip_next=1; continue ;;
        -arch) skip_next=1; continue ;;
        --gcc-toolchain=*) continue ;;
        --sysroot=*) continue ;;
        --sysroot) skip_next=1; continue ;;
        -isysroot) skip_next=1; continue ;;
        *) args="$args $arg" ;;
    esac
done
exec CLANG_UNWRAPPED -target CLANG_TARGET \
    -I CLANG_BUILTIN_INCLUDE \
    -isystem SYSROOT/usr/include \
    -isysroot SYSROOT \
    -F SDK_FRAMEWORKS \
    -mmacosx-version-min=MACOS_VERSION \
    -Wno-elaborated-enum-base \
    -DkIOMainPortDefault=kIOMasterPortDefault \
    -B WRAPPER_DIR \
    $args
WRAPPER
    sed -i "s|CLANG_UNWRAPPED|${llvmPackages.clang-unwrapped}/bin/clang|g" $TMPDIR/cross-wrapper/clang
    sed -i "s|CLANG_TARGET|${clangTarget}|g" $TMPDIR/cross-wrapper/clang
    sed -i "s|SYSROOT|${sdkRoot}|g" $TMPDIR/cross-wrapper/clang
    sed -i "s|SDK_FRAMEWORKS|$SDK_FRAMEWORKS|g" $TMPDIR/cross-wrapper/clang
    sed -i "s|MACOS_VERSION|${macosVersion}|g" $TMPDIR/cross-wrapper/clang
    sed -i "s|WRAPPER_DIR|$TMPDIR/cross-wrapper|g" $TMPDIR/cross-wrapper/clang
    sed -i "s|CLANG_BUILTIN_INCLUDE|${clangBuiltinInclude}|g" $TMPDIR/cross-wrapper/clang
    chmod +x $TMPDIR/cross-wrapper/clang

    # Create clang++ wrapper
    cat > $TMPDIR/cross-wrapper/clang++ << 'WRAPPER'
#!/bin/sh
args=""
skip_next=0
for arg in "$@"; do
    if [ $skip_next -eq 1 ]; then
        skip_next=0
        continue
    fi
    case "$arg" in
        --target=*) continue ;;
        -target=*) continue ;;
        --target) skip_next=1; continue ;;
        -target) skip_next=1; continue ;;
        -arch) skip_next=1; continue ;;
        --gcc-toolchain=*) continue ;;
        --sysroot=*) continue ;;
        --sysroot) skip_next=1; continue ;;
        -isysroot) skip_next=1; continue ;;
        *) args="$args $arg" ;;
    esac
done
exec CLANG_UNWRAPPED -target CLANG_TARGET \
    -nostdinc++ \
    -I CLANG_BUILTIN_INCLUDE \
    -isystem LIBCXX_INCLUDE \
    -isystem SYSROOT/usr/include \
    -isysroot SYSROOT \
    -stdlib=libc++ \
    -F SDK_FRAMEWORKS \
    -mmacosx-version-min=MACOS_VERSION \
    -Wno-elaborated-enum-base \
    -DkIOMainPortDefault=kIOMasterPortDefault \
    -DETIMEDOUT=60 \
    -B WRAPPER_DIR \
    $args
WRAPPER
    sed -i "s|CLANG_UNWRAPPED|${llvmPackages.clang-unwrapped}/bin/clang++|g" $TMPDIR/cross-wrapper/clang++
    sed -i "s|CLANG_TARGET|${clangTarget}|g" $TMPDIR/cross-wrapper/clang++
    sed -i "s|SYSROOT|${sdkRoot}|g" $TMPDIR/cross-wrapper/clang++
    sed -i "s|LIBCXX_INCLUDE|$LIBCXX_INCLUDE|g" $TMPDIR/cross-wrapper/clang++
    sed -i "s|SDK_FRAMEWORKS|$SDK_FRAMEWORKS|g" $TMPDIR/cross-wrapper/clang++
    sed -i "s|MACOS_VERSION|${macosVersion}|g" $TMPDIR/cross-wrapper/clang++
    sed -i "s|WRAPPER_DIR|$TMPDIR/cross-wrapper|g" $TMPDIR/cross-wrapper/clang++
    sed -i "s|CLANG_BUILTIN_INCLUDE|${clangBuiltinInclude}|g" $TMPDIR/cross-wrapper/clang++
    chmod +x $TMPDIR/cross-wrapper/clang++

    # Create ld64.lld wrapper
    cat > $TMPDIR/cross-wrapper/ld << 'WRAPPER'
#!/bin/sh
args=""
has_arch=0
has_platform=0
has_syslibroot=0

for arg in "$@"; do
    case "$arg" in
        -arch) has_arch=1 ;;
        -platform_version) has_platform=1 ;;
        -syslibroot) has_syslibroot=1 ;;
        -dynamic-linker*|--dynamic-linker*) continue ;;
        -m\ elf*|--hash-style*) continue ;;
        --eh-frame-hdr) continue ;;
        -z\ *) continue ;;
        --as-needed|--no-as-needed) continue ;;
        --build-id*) continue ;;
    esac
    args="$args $arg"
done

extra_args=""
if [ $has_arch -eq 0 ]; then
    extra_args="$extra_args -arch ARCH"
fi
if [ $has_platform -eq 0 ]; then
    extra_args="$extra_args -platform_version macos MACOS_VERSION MACOS_VERSION"
fi
if [ $has_syslibroot -eq 0 ]; then
    extra_args="$extra_args -syslibroot SYSROOT"
fi

exec LLD_PATH $extra_args \
    -F SDK_FRAMEWORKS \
    -L SYSROOT/usr/lib \
    $args
WRAPPER
    sed -i "s|LLD_PATH|${llvmPackages.lld}/bin/ld64.lld|g" $TMPDIR/cross-wrapper/ld
    sed -i "s|ARCH|${if targetArch == "aarch64" then "arm64" else "x86_64"}|g" $TMPDIR/cross-wrapper/ld
    sed -i "s|MACOS_VERSION|${macosVersion}|g" $TMPDIR/cross-wrapper/ld
    sed -i "s|SYSROOT|${sdkRoot}|g" $TMPDIR/cross-wrapper/ld
    sed -i "s|SDK_FRAMEWORKS|$SDK_FRAMEWORKS|g" $TMPDIR/cross-wrapper/ld
    chmod +x $TMPDIR/cross-wrapper/ld

    # LLVM tool wrappers
    ln -sf ${llvmPackages.llvm}/bin/llvm-ar $TMPDIR/cross-wrapper/ar
    ln -sf ${llvmPackages.llvm}/bin/llvm-ranlib $TMPDIR/cross-wrapper/ranlib
    ln -sf ${llvmPackages.llvm}/bin/llvm-nm $TMPDIR/cross-wrapper/nm
    ln -sf ${llvmPackages.llvm}/bin/llvm-strip $TMPDIR/cross-wrapper/strip
    ln -sf ${llvmPackages.llvm}/bin/llvm-objcopy $TMPDIR/cross-wrapper/objcopy
    ln -sf ${llvmPackages.llvm}/bin/llvm-install-name-tool $TMPDIR/cross-wrapper/install_name_tool
    ln -sf ${llvmPackages.llvm}/bin/llvm-lipo $TMPDIR/cross-wrapper/lipo
    ln -sf ${llvmPackages.llvm}/bin/llvm-otool $TMPDIR/cross-wrapper/otool

    # Create fake xcrun
    cat > $TMPDIR/cross-wrapper/xcrun << 'XCRUN'
#!/bin/sh
case "$*" in
    *--show-sdk-version*)
        echo "MACOS_VERSION"
        ;;
    *--show-sdk-path*)
        echo "SYSROOT"
        ;;
    *--show-sdk-build-version*)
        echo "20A241"
        ;;
    *--sdk*macosx*--find*)
        tool=$(echo "$*" | sed 's/.*--find //')
        if [ -x "$TMPDIR/cross-wrapper/$tool" ]; then
            echo "$TMPDIR/cross-wrapper/$tool"
        else
            echo "/usr/bin/$tool"
        fi
        ;;
    *)
        echo "xcrun: unknown arguments: $*" >&2
        exit 1
        ;;
esac
XCRUN
    sed -i "s|MACOS_VERSION|${macosVersion}|g" $TMPDIR/cross-wrapper/xcrun
    sed -i "s|SYSROOT|${sdkRoot}|g" $TMPDIR/cross-wrapper/xcrun
    chmod +x $TMPDIR/cross-wrapper/xcrun

    export PATH="$TMPDIR/cross-wrapper:$PATH"
    export CC="$TMPDIR/cross-wrapper/clang"
    export CXX="$TMPDIR/cross-wrapper/clang++"
    export AR="$TMPDIR/cross-wrapper/ar"
    export RANLIB="$TMPDIR/cross-wrapper/ranlib"
    export LD="$TMPDIR/cross-wrapper/ld"
  '';

  enableParallelBuilding = true;

  installPhase = ''
    ninja install
  '';

  meta = with lib; {
    description = "Qt 6 SVG module built as static libraries for macOS ${targetArch} (cross-compiled)";
    homepage = "https://www.qt.io/";
    license = with licenses; [ lgpl3Only gpl3Only ];
    platforms = platforms.linux;
  };
}
