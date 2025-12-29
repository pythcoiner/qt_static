{ lib
, stdenv
, qt6Source      # Local qtbase source
, qtVersion
, qt6HostTools   # Linux Qt build needed for moc, rcc, uic
, mingwPkgs      # pkgsCross.mingwW64

# Build tools (native, run on build machine)
, cmake
, ninja
, perl
, python3
, pkg-config
, which
}:

let
  # Get the cross compiler
  crossCC = mingwPkgs.stdenv.cc;
  targetPrefix = crossCC.targetPrefix;
  # mingw sysroot with headers
  mingwSysroot = "${crossCC}/${targetPrefix}";
in

stdenv.mkDerivation rec {
  pname = "qt6-static-windows";
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

  # No postPatch needed - fixes are applied directly in qt-src/qtbase

  # All native build inputs (run on the build machine)
  nativeBuildInputs = [
    cmake
    ninja
    perl
    python3
    pkg-config
    which
    crossCC  # The cross compiler itself is a native build input
  ];

  # Cross-compilation environment
  depsBuildBuild = [
    qt6HostTools  # Host Qt tools for moc, rcc, uic
  ];

  cmakeFlags = [
    # Static build configuration
    "-DBUILD_SHARED_LIBS=OFF"
    "-DFEATURE_static=ON"
    "-DFEATURE_static_runtime=ON"

    # Build only what we need
    "-DQT_BUILD_EXAMPLES=OFF"
    "-DQT_BUILD_TESTS=OFF"
    "-DQT_BUILD_BENCHMARKS=OFF"
    "-DQT_BUILD_MANUAL_TESTS=OFF"

    # Modules to build
    "-DQT_BUILD_SUBMODULES=qtbase"

    # Cross-compilation settings
    "-DCMAKE_SYSTEM_NAME=Windows"
    "-DCMAKE_CROSSCOMPILING=ON"
    "-DCMAKE_C_COMPILER=${crossCC}/bin/${targetPrefix}gcc"
    "-DCMAKE_CXX_COMPILER=${crossCC}/bin/${targetPrefix}g++"
    "-DCMAKE_RC_COMPILER=${crossCC}/bin/${targetPrefix}windres"
    "-DCMAKE_AR=${crossCC}/bin/${targetPrefix}ar"
    "-DCMAKE_RANLIB=${crossCC}/bin/${targetPrefix}ranlib"
    "-DCMAKE_STRIP=${crossCC}/bin/${targetPrefix}strip"

    # Set find root path for cross-compilation (where to find Windows headers/libs)
    "-DCMAKE_FIND_ROOT_PATH=${mingwSysroot}"
    "-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER"
    "-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY"
    "-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY"

    # Host Qt tools path (needed for moc, rcc, uic during cross-compilation)
    "-DQT_HOST_PATH=${qt6HostTools}"
    "-DQT_HOST_PATH_CMAKE_DIR=${qt6HostTools}/lib/cmake"

    # Features for Windows
    "-DQT_FEATURE_gui=ON"
    "-DQT_FEATURE_widgets=ON"
    "-DQT_FEATURE_accessibility=ON"

    # Use bundled libraries (safer for cross-compilation)
    "-DFEATURE_system_zlib=OFF"
    "-DFEATURE_system_pcre2=OFF"
    "-DFEATURE_system_harfbuzz=OFF"
    "-DFEATURE_system_freetype=OFF"
    "-DFEATURE_system_png=OFF"
    "-DFEATURE_system_jpeg=OFF"

    # DirectWrite - enable with dwrite.h patch
    "-DQT_FEATURE_directwrite=ON"
    "-DQT_FEATURE_directwrite2=ON"
    "-DQT_FEATURE_directwrite3=ON"

    # Direct2D - must be enabled when DirectWrite is enabled (Qt bug: incomplete type otherwise)
    "-DQT_FEATURE_direct2d=ON"
    "-DQT_FEATURE_direct2d1_1=ON"

    # Disable OpenGL (not available in mingw cross-compile without ANGLE)
    "-DINPUT_opengl=no"
    "-DQT_FEATURE_opengl=OFF"
    "-DQT_FEATURE_opengl_dynamic=OFF"
    "-DQT_FEATURE_opengles2=OFF"
    "-DQT_FEATURE_opengles3=OFF"
    "-DQT_FEATURE_openvg=OFF"

    # Disable features that are problematic for cross-compilation
    "-DQT_FEATURE_dbus=OFF"
    "-DQT_FEATURE_sql=OFF"
    "-DQT_FEATURE_icu=OFF"
    "-DQT_FEATURE_ssl=OFF"
    "-DQT_FEATURE_openssl=OFF"
    "-DQT_FEATURE_schannel=OFF"
    "-DQT_FEATURE_network=OFF"  # Disable network module entirely (avoids TLS plugins)

    # Font rendering
    "-DQT_FEATURE_freetype=ON"
    "-DQT_FEATURE_harfbuzz=ON"

    # Image formats
    "-DQT_FEATURE_png=ON"
    "-DQT_FEATURE_jpeg=ON"

    # Build type
    "-DCMAKE_BUILD_TYPE=Release"

    # Use Ninja generator
    "-GNinja"
  ];

  preConfigure = ''
    # Set up cross-compilation environment
    export CC="${crossCC}/bin/${targetPrefix}gcc"
    export CXX="${crossCC}/bin/${targetPrefix}g++"
    export AR="${crossCC}/bin/${targetPrefix}ar"
    export RANLIB="${crossCC}/bin/${targetPrefix}ranlib"
    export WINDRES="${crossCC}/bin/${targetPrefix}windres"
    export STRIP="${crossCC}/bin/${targetPrefix}strip"

    # Add host Qt tools to PATH
    export PATH="${qt6HostTools}/bin:$PATH"

    # Ensure mingw headers are found (sys-include contains Windows API headers)
    export CFLAGS="-I${mingwSysroot}/sys-include $CFLAGS"
    export CXXFLAGS="-I${mingwSysroot}/sys-include $CXXFLAGS"
  '';

  enableParallelBuilding = true;

  installPhase = ''
    ninja install
  '';

  meta = with lib; {
    description = "Qt 6 built as static libraries for Windows (cross-compiled)";
    homepage = "https://www.qt.io/";
    license = with licenses; [ lgpl3Only gpl3Only ];
    platforms = platforms.linux;  # Build platform is Linux
    maintainers = [];
  };
}
