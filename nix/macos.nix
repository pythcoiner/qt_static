{ lib
, stdenv
, qt6Source
, qtVersion
, qt6HostTools   # Linux Qt build needed for moc, rcc, uic
, targetArch     # "aarch64" or "x86_64"
, xcode          # darwin.xcode_12_2 - the Xcode SDK
, llvmPackages   # LLVM toolchain (clang, lld, etc.)

# Build tools (native, run on build machine)
, cmake
, ninja
, perl
, python3
, pkg-config
, which
}:

let
  # Darwin target configuration
  targetTriple = "${targetArch}-apple-darwin";

  # SDK path from Xcode
  sdkRoot = "${xcode}/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk";

  # libc++ headers from Xcode toolchain
  libcxxInclude = "${xcode}/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/include/c++/v1";

  # Minimum macOS version (SDK 11.0 from Xcode 12.2)
  macosVersion = "11.0";

  # Clang target string
  clangTarget = "${targetArch}-apple-macos${macosVersion}";

  # Clang builtin include directory (for stdarg.h, stddef.h, etc.)
  # Note: clang-unwrapped.lib contains the actual lib directory with builtins
  clangBuiltinInclude = "${llvmPackages.clang-unwrapped.lib}/lib/clang/18/include";

in

stdenv.mkDerivation rec {
  pname = "qt6-static-macos-${targetArch}";
  version = qtVersion;

  src = qt6Source;

  sourceRoot = "source";

  # Copy local source and make writable
  unpackPhase = ''
    runHook preUnpack
    cp -r $src source
    chmod -R u+w source
    runHook postUnpack
  '';

  # All native build inputs (run on the build machine)
  nativeBuildInputs = [
    cmake
    ninja
    perl
    python3
    pkg-config
    which
    llvmPackages.clang
    llvmPackages.lld
    llvmPackages.llvm      # For llvm-ar, llvm-nm, etc.
    llvmPackages.bintools  # Additional binary tools
  ];

  # Build dependencies
  depsBuildBuild = [
    qt6HostTools
    xcode  # SDK needed at build time
  ];

  cmakeFlags = [
    # Static build configuration
    "-DBUILD_SHARED_LIBS=OFF"
    "-DFEATURE_static=ON"
    "-DFEATURE_static_runtime=OFF"

    # Build only what we need
    "-DQT_BUILD_EXAMPLES=OFF"
    "-DQT_BUILD_TESTS=OFF"
    "-DQT_BUILD_BENCHMARKS=OFF"
    "-DQT_BUILD_MANUAL_TESTS=OFF"

    # Modules to build
    "-DQT_BUILD_SUBMODULES=qtbase"

    # Cross-compilation settings
    "-DCMAKE_SYSTEM_NAME=Darwin"
    "-DCMAKE_SYSTEM_PROCESSOR=${targetArch}"
    "-DCMAKE_CROSSCOMPILING=ON"
    "-DCMAKE_OSX_DEPLOYMENT_TARGET=${macosVersion}"
    "-DCMAKE_OSX_SYSROOT=${sdkRoot}"

    # Find root path for cross-compilation
    "-DCMAKE_FIND_ROOT_PATH=${sdkRoot}"
    "-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER"
    "-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY"
    "-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY"

    # Host Qt tools path (needed for moc, rcc, uic during cross-compilation)
    "-DQT_HOST_PATH=${qt6HostTools}"
    "-DQT_HOST_PATH_CMAKE_DIR=${qt6HostTools}/lib/cmake"

    # Bypass xcrun checks by setting cached values directly
    "-DQT_INTERNAL_APPLE_SDK_VERSION:STRING=${macosVersion}"
    "-DQT_INTERNAL_XCODE_VERSION:STRING=12.2"
    "-DQT_NO_APPLE_SDK_MIN_VERSION_CHECK=ON"
    "-DQT_NO_APPLE_SDK_MAX_VERSION_CHECK=ON"
    "-DQT_NO_XCODE_MIN_VERSION_CHECK=ON"
    "-DQT_FORCE_WARN_APPLE_SDK_AND_XCODE_CHECK=ON"
    "-DCMAKE_XCODE_ATTRIBUTE_DEVELOPMENT_TEAM="

    # Force-pass compile tests that fail in cross-compilation
    "-DTEST_atomicfptr=ON"

    # Features for macOS
    "-DQT_FEATURE_gui=ON"
    "-DQT_FEATURE_widgets=ON"
    "-DQT_FEATURE_accessibility=ON"

    # macOS-specific: use Cocoa
    "-DQT_FEATURE_cocoa=ON"

    # Use bundled libraries for cross-compilation reliability
    "-DFEATURE_system_zlib=OFF"
    "-DFEATURE_system_pcre2=OFF"
    "-DFEATURE_system_harfbuzz=OFF"
    "-DFEATURE_system_freetype=OFF"
    "-DFEATURE_system_png=OFF"
    "-DFEATURE_system_jpeg=OFF"

    # Font rendering (CoreText on macOS)
    "-DQT_FEATURE_coretext=ON"
    "-DQT_FEATURE_freetype=ON"
    "-DQT_FEATURE_harfbuzz=ON"

    # Image formats
    "-DQT_FEATURE_png=ON"
    "-DQT_FEATURE_jpeg=ON"

    # Disable features not needed for cross-compilation
    "-DQT_FEATURE_dbus=OFF"
    "-DQT_FEATURE_sql=OFF"
    "-DQT_FEATURE_icu=OFF"
    "-DQT_FEATURE_ssl=OFF"
    "-DQT_FEATURE_openssl=OFF"
    "-DQT_FEATURE_securetransport=OFF"
    "-DQT_FEATURE_network=OFF"
    "-DQT_FEATURE_printsupport=OFF"
    "-DQT_FEATURE_cups=OFF"
    "-DQT_FEATURE_concurrent=OFF"
    "-DQT_FEATURE_testlib=OFF"

    # Disable X11/Wayland (not applicable to macOS)
    "-DQT_FEATURE_xcb=OFF"
    "-DQT_FEATURE_wayland=OFF"

    # Graphics APIs
    "-DQT_FEATURE_opengl=OFF"
    "-DQT_FEATURE_metal=ON"        # macOS SDK has Metal support
    "-DQT_FEATURE_vulkan=OFF"

    # Build type
    "-DCMAKE_BUILD_TYPE=Release"

    # Use Ninja generator
    "-GNinja"
  ];

  # Create wrapper scripts for cross-compilation toolchain
  preConfigure = ''
    # Set SDK root
    export SDKROOT="${sdkRoot}"

    # Add host Qt tools to PATH
    export PATH="${qt6HostTools}/bin:$PATH"

    # Framework search path in the SDK
    SDK_FRAMEWORKS="${sdkRoot}/System/Library/Frameworks"

    # libc++ headers from Xcode toolchain
    LIBCXX_INCLUDE="${xcode}/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/include/c++/v1"

    # Create wrapper directory
    mkdir -p $TMPDIR/cross-wrapper

    # Create compatibility header for macOS 12+ APIs not in SDK 11
    cat > $TMPDIR/cross-wrapper/macos_compat.h << 'COMPAT_HEADER'
#ifndef MACOS_COMPAT_H
#define MACOS_COMPAT_H

#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

#if __MAC_OS_X_VERSION_MAX_ALLOWED < 120000

// Compatibility for NSScreen.safeAreaInsets (macOS 12.0+)
@interface NSScreen (SafeAreaCompat)
@property (readonly) NSEdgeInsets safeAreaInsets;
@end

// Informal protocol to declare applicationSupportsSecureRestorableState:
// so the compiler knows its return type when calling on id
@interface NSObject (SecureRestorableStateCompat)
- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)application;
@end

#endif // __MAC_OS_X_VERSION_MAX_ALLOWED < 120000

#endif // MACOS_COMPAT_H
COMPAT_HEADER

    # Create implementation file for compatibility APIs
    cat > $TMPDIR/cross-wrapper/macos_compat.m << 'COMPAT_IMPL'
#import "macos_compat.h"

#if __MAC_OS_X_VERSION_MAX_ALLOWED < 120000
@implementation NSScreen (SafeAreaCompat)
- (NSEdgeInsets)safeAreaInsets {
    // Return zero insets on older SDKs
    return NSEdgeInsetsZero;
}
@end
#endif
COMPAT_IMPL

    # Create clang wrapper that sets the correct target and sysroot
    cat > $TMPDIR/cross-wrapper/clang << 'WRAPPER'
#!/bin/sh
# Filter out conflicting flags from cmake that interfere with cross-compilation
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
# Order matters for #include_next to work:
# 1. Clang builtins (stdarg.h, etc) - highest priority
# 2. System headers from SDK
# -Wno-elaborated-enum-base: suppress CF_ENUM compatibility issue with newer clang
# -DkIOMainPortDefault: compatibility define for Qt 6.8+ with older SDKs
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
    # Substitute paths in clang wrapper
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
# Filter out conflicting flags from cmake that interfere with cross-compilation
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
# Use -nostdinc++ to take full control of C++ include paths
# Order matters for #include_next to work:
# 1. Clang builtins (stdarg.h, etc) - highest priority
# 2. libc++ headers - use #include_next for system headers
# 3. System headers from SDK - found via #include_next
# Compatibility defines:
# -Wno-elaborated-enum-base: suppress CF_ENUM compatibility issue with newer clang
# -DkIOMainPortDefault: compatibility for Qt 6.8+ with older SDKs (renamed in macOS 12)
# -DETIMEDOUT=60: errno constant needed for qfutex (from sys/errno.h)
# For Objective-C++ (.mm files), include compatibility header for macOS 12+ APIs
compat_include=""
for arg in $args; do
    case "$arg" in
        *.mm) compat_include="-include WRAPPER_DIR/macos_compat.h" ;;
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
    $compat_include \
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

    # Create ld64.lld wrapper (using lld's MachO linker)
    # The wrapper adds necessary flags and filters out incompatible ones
    cat > $TMPDIR/cross-wrapper/ld << 'WRAPPER'
#!/bin/sh
# ld wrapper for macOS cross-compilation using lld
# Filters out Linux-specific flags and adds darwin-specific ones

args=""
has_arch=0
has_platform=0
has_syslibroot=0

for arg in "$@"; do
    case "$arg" in
        -arch) has_arch=1 ;;
        -platform_version) has_platform=1 ;;
        -syslibroot) has_syslibroot=1 ;;
        # Filter out Linux ELF-specific flags
        -dynamic-linker*|--dynamic-linker*) continue ;;
        -m\ elf*|--hash-style*) continue ;;
        --eh-frame-hdr) continue ;;
        -z\ *) continue ;;
        --as-needed|--no-as-needed) continue ;;
        --build-id*) continue ;;
    esac
    args="$args $arg"
done

# Add required flags if not present
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

    # Create LLVM tool wrappers
    ln -sf ${llvmPackages.llvm}/bin/llvm-ar $TMPDIR/cross-wrapper/ar
    ln -sf ${llvmPackages.llvm}/bin/llvm-ranlib $TMPDIR/cross-wrapper/ranlib
    ln -sf ${llvmPackages.llvm}/bin/llvm-nm $TMPDIR/cross-wrapper/nm
    ln -sf ${llvmPackages.llvm}/bin/llvm-strip $TMPDIR/cross-wrapper/strip
    ln -sf ${llvmPackages.llvm}/bin/llvm-objcopy $TMPDIR/cross-wrapper/objcopy
    ln -sf ${llvmPackages.llvm}/bin/llvm-install-name-tool $TMPDIR/cross-wrapper/install_name_tool
    ln -sf ${llvmPackages.llvm}/bin/llvm-lipo $TMPDIR/cross-wrapper/lipo
    ln -sf ${llvmPackages.llvm}/bin/llvm-otool $TMPDIR/cross-wrapper/otool

    # Create fake xcrun for SDK version detection
    cat > $TMPDIR/cross-wrapper/xcrun << 'XCRUN'
#!/bin/sh
# Fake xcrun for cross-compilation
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
    description = "Qt 6 built as static libraries for macOS ${targetArch} (cross-compiled with clang/lld)";
    homepage = "https://www.qt.io/";
    license = with licenses; [ lgpl3Only gpl3Only ];
    platforms = platforms.linux;  # Build platform is Linux
    maintainers = [];
  };
}
