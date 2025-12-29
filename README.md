# Qt 6 Static Build

Reproducible Nix builds for Qt 6 static libraries targeting Linux and Windows (cross-compiled from Linux).

## Quick Start

```bash
# Clone this repo
git clone https://github.com/pythcoiner/qt_static.git
cd qt_static

# Build (fetches Qt source automatically)
./build.sh           # Build both Linux and Windows
./build.sh linux     # Build Linux only
./build.sh windows   # Build Windows only
```

## Requirements

- [Nix](https://nixos.org/download.html) with flakes enabled

Enable flakes in `~/.config/nix/nix.conf`:
```
experimental-features = nix-command flakes
```

## Output

Static libraries are packaged in `dist/`:

```
dist/
├── linux/
│   ├── bin/           # Qt tools (moc, rcc, uic)
│   ├── include/       # Qt headers
│   ├── lib/
│   │   ├── libQt6Core.a
│   │   ├── libQt6Gui.a
│   │   ├── libQt6Widgets.a
│   │   └── cmake/Qt6/ # CMake config files
│   └── plugins/
│       └── platforms/ # xcb, wayland, etc.
└── windows/
    ├── bin/
    ├── include/
    ├── lib/
    │   ├── libQt6Core.a
    │   ├── libQt6Gui.a
    │   ├── libQt6Widgets.a
    │   └── cmake/Qt6/
    └── plugins/
        └── platforms/ # qwindows, qdirect2d
```

## CMake Integration

Use the static Qt6 in your CMake project:

```cmake
# Point CMake to the static Qt6
set(CMAKE_PREFIX_PATH "/path/to/qt_static/dist/linux")
# or for Windows cross-compile:
# set(CMAKE_PREFIX_PATH "/path/to/qt_static/dist/windows")

find_package(Qt6 REQUIRED COMPONENTS Core Gui Widgets)

add_executable(myapp main.cpp)
target_link_libraries(myapp Qt6::Core Qt6::Gui Qt6::Widgets)
```

Or pass it on the command line:

```bash
cmake -DCMAKE_PREFIX_PATH=/path/to/qt_static/dist/linux ..
```

## Configuration

| Feature | Linux | Windows |
|---------|-------|---------|
| Qt Version | 6.8.3 | 6.8.3 |
| Modules | Core, Gui, Widgets | Core, Gui, Widgets |
| Graphics | OpenGL, Vulkan | Direct2D, DirectWrite |
| Fonts | Fontconfig, FreeType, HarfBuzz | FreeType, HarfBuzz |

## Project Structure

```
qt_static/
├── build.sh          # Build script (fetches source + builds + packages)
├── flake.nix         # Nix flake definition
├── nix/
│   ├── linux.nix     # Linux build configuration
│   └── windows.nix   # Windows cross-compile configuration
├── qt-src/           # Qt source (created by build.sh)
│   └── qtbase/       # Patched qtbase
└── dist/             # Build output (created by build.sh)
    ├── linux/        # Linux static Qt
    └── windows/      # Windows static Qt
```

## Patches Applied

The Qt source includes fixes for MinGW cross-compilation:
- `dwrite.h` include fix for `IDWriteFontFace` type (Windows only)

## License

Qt is licensed under LGPL-3.0 / GPL-3.0. See [Qt Licensing](https://www.qt.io/licensing/).
