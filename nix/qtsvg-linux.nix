{ lib
, stdenv
, qtSvgSource
, qtVersion
, qt6Linux       # Installed qtbase to build against

# Build tools
, cmake
, ninja
, perl
, python3
, pkg-config
, which
}:

stdenv.mkDerivation rec {
  pname = "qt6-svg-static-linux";
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
  ];

  buildInputs = [
    qt6Linux
  ];

  cmakeFlags = [
    "-DCMAKE_PREFIX_PATH=${qt6Linux}"
    "-DQT_BUILD_EXAMPLES=OFF"
    "-DQT_BUILD_TESTS=OFF"
    "-DCMAKE_BUILD_TYPE=Release"
    "-GNinja"
  ];

  enableParallelBuilding = true;

  installPhase = ''
    ninja install
  '';

  meta = with lib; {
    description = "Qt 6 SVG module built as static libraries for Linux";
    homepage = "https://www.qt.io/";
    license = with licenses; [ lgpl3Only gpl3Only ];
    platforms = platforms.linux;
  };
}
