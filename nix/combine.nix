{ lib
, stdenv
, qtbase
, qtsvg
, name ? "qt6-static-combined"
}:

stdenv.mkDerivation {
  pname = name;
  version = qtbase.version;

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    mkdir -p $out

    # Copy qtbase first (the base)
    cp -rL ${qtbase}/* $out/
    chmod -R u+w $out

    # Merge qtsvg on top (adds lib/cmake/Qt6Svg*, lib/*.a, include/QtSvg*, etc.)
    cp -rLT ${qtsvg}/ $out/
  '';

  meta = with lib; {
    description = "Qt 6 static (qtbase + qtsvg combined)";
    homepage = "https://www.qt.io/";
    license = with licenses; [ lgpl3Only gpl3Only ];
  };
}
