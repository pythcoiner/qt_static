# Qt 6 Static Build

Reproducible Nix builds for Qt 6 static libraries targeting Linux and Windows 
(cross-compiled from Linux).

## Quick Start

```bash
# Clone this repo
git clone https://github.com/pythcoiner/qt_static.git
cd qt_static

# Build both targets
./build.sh all
```

## Requirements

- [Nix](https://nixos.org/download.html) with flakes enabled

Enable flakes in `~/.config/nix/nix.conf`:
```
experimental-features = nix-command flakes
```

## Commands

```
Usage: ./build.sh [linux|windows|all|hash|sign|verify]

  linux    Build Linux static Qt only
  windows  Build Windows static Qt only (cross-compiled)
  all      Build both targets (default)
  hash     Compute hashes for existing builds in dist/
  sign     GPG sign hash manifest
  verify   Verify hashes and GPG signature
```

### Build Commands

```bash
./build.sh linux     # Build Linux only
./build.sh windows   # Build Windows only (cross-compiled)
./build.sh all       # Build both targets
```

### Reproducibility Commands

```bash
./build.sh hash      # Generate dist/SHA256SUMS manifest
./build.sh sign      # GPG sign manifest -> dist/SHA256SUMS.sig
./build.sh verify    # Verify hashes and signature
```

## Reproducibility

This project uses Nix to ensure reproducible builds. Given the same inputs 
(Qt source, Nix packages), the build will produce identical outputs.

### Verifying Builds

After building, the `hash` command generates a manifest with SHA256 hashes for 
all files:

```bash
./build.sh hash
```

Output:
```
=== Target Hashes ===
linux  a1b2c3d4e5f6...
windows f6e5d4c3b2a1...
```

Compare these hashes with official releases or other builders to verify
reproducibility.

### Signing Releases

Maintainers can sign the manifest:

```bash
./build.sh sign
```

### Verifying Releases

Users can verify the signature and file integrity:

```bash
./build.sh verify
```

This checks:
1. GPG signature on `dist/SHA256SUMS.sig` (if present)
2. All file hashes match `dist/SHA256SUMS`

Manual verification with GPG:

```bash
# Verify signature
gpg --verify dist/SHA256SUMS.sig dist/SHA256SUMS

# Verify file hashes
(cd dist && sha256sum -c SHA256SUMS)
```

## Output

Static libraries are packaged in `dist/`:

```
dist/
├── SHA256SUMS          # Hash manifest (all targets)
├── SHA256SUMS.sig      # GPG signature
├── linux/
│   ├── bin/            # Qt tools (moc, rcc, uic)
│   ├── include/        # Qt headers
│   ├── lib/
│   │   ├── libQt6Core.a
│   │   ├── libQt6Gui.a
│   │   ├── libQt6Widgets.a
│   │   └── cmake/Qt6/  # CMake config files
│   └── plugins/
│       └── platforms/  # xcb, wayland, etc.
└── windows/
    ├── bin/
    ├── include/
    ├── lib/
    │   ├── libQt6Core.a
    │   ├── libQt6Gui.a
    │   ├── libQt6Widgets.a
    │   └── cmake/Qt6/
    └── plugins/
        └── platforms/  # qwindows, qdirect2d
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

```
+-------------------+-------------------------+-------------------------+
| Feature           | Linux                   | Windows                 |
+-------------------+-------------------------+-------------------------+
| Qt Version        | 6.8.3                   | 6.8.3                   |
| Modules           | Core, Gui, Widgets      | Core, Gui, Widgets      |
| Graphics          | OpenGL, Vulkan          | Direct2D, DirectWrite   |
| Fonts             | Fontconfig, FreeType,   | FreeType, HarfBuzz      |
|                   | HarfBuzz                |                         |
+-------------------+-------------------------+-------------------------+
```

## Project Structure

```
qt_static/
├── build.sh          # Build script
├── flake.nix         # Nix flake definition
├── nix/
│   ├── linux.nix     # Linux build configuration
│   └── windows.nix   # Windows cross-compile configuration
├── qt-src/           # Qt source (fetched by build.sh)
│   └── qtbase/       # Patched qtbase
└── dist/             # Build output
    ├── SHA256SUMS    # Hash manifest
    ├── linux/        # Linux static Qt
    └── windows/      # Windows static Qt
```

## Patches Applied

The Qt source includes fixes for MinGW cross-compilation:
- `dwrite.h` include fix for `IDWriteFontFace` type (Windows only)

## License

Qt is licensed under LGPL-3.0 / GPL-3.0. See [Qt Licensing](https://www.qt.io/licensing/).
