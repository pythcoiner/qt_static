{ lib
, stdenv
, qt6Source
, qtVersion

# Build tools
, cmake
, ninja
, perl
, python3
, pkg-config
, which

# X11 dependencies
, xorg
, libxkbcommon

# Wayland dependencies
, wayland
, wayland-protocols
, wayland-scanner

# Graphics
, mesa
, libGL
, vulkan-headers
, vulkan-loader
, libdrm

# Fonts
, fontconfig
, freetype
, harfbuzz

# Other dependencies
, dbus
, at-spi2-core
, libinput
, mtdev
, systemdLibs  # for libudev
, zlib
, pcre2
, double-conversion
, libb2
, openssl
, libpng
, libjpeg
, sqlite
, glib
, libxshmfence
}:

stdenv.mkDerivation rec {
  pname = "qt6-static-linux";
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

  nativeBuildInputs = [
    cmake
    ninja
    perl
    python3
    pkg-config
    which
    wayland-scanner
  ];

  buildInputs = [
    # X11
    xorg.libX11
    xorg.libXext
    xorg.libXrender
    xorg.libXi
    xorg.libXcursor
    xorg.libXrandr
    xorg.libXinerama
    xorg.libXfixes
    xorg.libXcomposite
    xorg.libXdamage
    xorg.libxcb
    xorg.xcbutil
    xorg.xcbutilwm
    xorg.xcbutilimage
    xorg.xcbutilkeysyms
    xorg.xcbutilrenderutil
    xorg.xcbutilcursor
    xorg.libSM
    xorg.libICE
    libxkbcommon

    # Wayland
    wayland
    wayland-protocols

    # Graphics
    mesa
    libGL
    vulkan-headers
    vulkan-loader
    libdrm
    libxshmfence

    # Fonts
    fontconfig
    freetype
    harfbuzz

    # Other
    dbus
    at-spi2-core
    libinput
    mtdev
    systemdLibs
    zlib
    pcre2
    double-conversion
    libb2
    openssl
    libpng
    libjpeg
    sqlite
    glib
  ];

  cmakeFlags = [
    # Static build configuration
    "-DBUILD_SHARED_LIBS=OFF"
    "-DFEATURE_static=ON"
    "-DFEATURE_static_runtime=OFF"  # Don't statically link libc

    # Build only what we need
    "-DQT_BUILD_EXAMPLES=OFF"
    "-DQT_BUILD_TESTS=OFF"
    "-DQT_BUILD_BENCHMARKS=OFF"
    "-DQT_BUILD_MANUAL_TESTS=OFF"
    "-DQT_BUILD_MINIMAL_STATIC_TESTS=OFF"

    # Modules to build (qtbase only for Core, Gui, Widgets)
    "-DQT_BUILD_SUBMODULES=qtbase"

    # Features
    "-DQT_FEATURE_gui=ON"
    "-DQT_FEATURE_widgets=ON"
    "-DQT_FEATURE_dbus=ON"
    "-DQT_FEATURE_accessibility=ON"

    # X11 support
    "-DQT_FEATURE_xcb=ON"
    "-DQT_FEATURE_xcb_xlib=ON"
    "-DQT_FEATURE_xkbcommon=ON"
    "-DQT_FEATURE_xkbcommon_x11=ON"

    # Wayland support
    "-DQT_FEATURE_wayland=ON"

    # Graphics
    "-DQT_FEATURE_opengl=ON"
    "-DQT_FEATURE_opengles2=OFF"
    "-DQT_FEATURE_vulkan=ON"

    # Font rendering
    "-DQT_FEATURE_fontconfig=ON"
    "-DQT_FEATURE_freetype=ON"
    "-DQT_FEATURE_harfbuzz=ON"

    # Image formats
    "-DQT_FEATURE_png=ON"
    "-DQT_FEATURE_jpeg=ON"

    # Other features
    "-DQT_FEATURE_icu=OFF"
    "-DQT_FEATURE_pcre2=ON"
    "-DQT_FEATURE_ssl=ON"
    "-DQT_FEATURE_openssl=ON"
    "-DQT_FEATURE_openssl_linked=ON"
    "-DQT_FEATURE_sql=ON"
    "-DQT_FEATURE_sql_sqlite=ON"

    # Build type
    "-DCMAKE_BUILD_TYPE=Release"

    # Use Ninja generator
    "-GNinja"
  ];

  # Fix up pkg-config paths
  preConfigure = ''
    export PKG_CONFIG_PATH="${lib.makeSearchPath "lib/pkgconfig" buildInputs}:${lib.makeSearchPath "share/pkgconfig" buildInputs}:$PKG_CONFIG_PATH"
  '';

  # Ninja parallel build
  enableParallelBuilding = true;

  # Install
  installPhase = ''
    ninja install
  '';

  meta = with lib; {
    description = "Qt 6 built as static libraries for Linux";
    homepage = "https://www.qt.io/";
    license = with licenses; [ lgpl3Only gpl3Only ];
    platforms = platforms.linux;
    maintainers = [];
  };
}
