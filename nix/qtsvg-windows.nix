{ lib
, stdenv
, qtSvgSource
, qtVersion
, qt6Linux       # Linux Qt (host tools: moc, rcc, uic)
, qt6Windows     # Installed qtbase for Windows to build against
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
  crossCC = mingwPkgs.stdenv.cc;
  targetPrefix = crossCC.targetPrefix;
  mingwSysroot = "${crossCC}/${targetPrefix}";
in

stdenv.mkDerivation rec {
  pname = "qt6-svg-static-windows";
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
    crossCC
  ];

  depsBuildBuild = [
    qt6Linux
  ];

  cmakeFlags = [
    "-DCMAKE_PREFIX_PATH=${qt6Windows}"

    "-DQT_BUILD_EXAMPLES=OFF"
    "-DQT_BUILD_TESTS=OFF"

    # Cross-compilation settings
    "-DCMAKE_SYSTEM_NAME=Windows"
    "-DCMAKE_CROSSCOMPILING=ON"
    "-DCMAKE_C_COMPILER=${crossCC}/bin/${targetPrefix}gcc"
    "-DCMAKE_CXX_COMPILER=${crossCC}/bin/${targetPrefix}g++"
    "-DCMAKE_RC_COMPILER=${crossCC}/bin/${targetPrefix}windres"
    "-DCMAKE_AR=${crossCC}/bin/${targetPrefix}ar"
    "-DCMAKE_RANLIB=${crossCC}/bin/${targetPrefix}ranlib"
    "-DCMAKE_STRIP=${crossCC}/bin/${targetPrefix}strip"

    "-DCMAKE_FIND_ROOT_PATH=${mingwSysroot};${qt6Windows}"
    "-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER"
    "-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY"
    "-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY"

    # Host Qt tools path
    "-DQT_HOST_PATH=${qt6Linux}"
    "-DQT_HOST_PATH_CMAKE_DIR=${qt6Linux}/lib/cmake"

    "-DCMAKE_BUILD_TYPE=Release"
    "-GNinja"
  ];

  preConfigure = ''
    export CC="${crossCC}/bin/${targetPrefix}gcc"
    export CXX="${crossCC}/bin/${targetPrefix}g++"
    export AR="${crossCC}/bin/${targetPrefix}ar"
    export RANLIB="${crossCC}/bin/${targetPrefix}ranlib"
    export WINDRES="${crossCC}/bin/${targetPrefix}windres"
    export STRIP="${crossCC}/bin/${targetPrefix}strip"

    export PATH="${qt6Linux}/bin:$PATH"

    export CFLAGS="-I${mingwSysroot}/sys-include $CFLAGS"
    export CXXFLAGS="-I${mingwSysroot}/sys-include $CXXFLAGS"
  '';

  enableParallelBuilding = true;

  installPhase = ''
    ninja install
  '';

  meta = with lib; {
    description = "Qt 6 SVG module built as static libraries for Windows (cross-compiled)";
    homepage = "https://www.qt.io/";
    license = with licenses; [ lgpl3Only gpl3Only ];
    platforms = platforms.linux;
  };
}
