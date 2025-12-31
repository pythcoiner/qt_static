# Qt 6 Static Build

Reproducible Nix builds for Qt 6 static libraries targeting Linux, Windows,
and macOS (all cross-compiled from Linux).

## Branches

```
+--------+------------+-------+------------------------------------------------+
| Branch | Qt Version | glibc | Compatible Linux Distros                       |
+--------+------------+-------+------------------------------------------------+
| 6.8.3  | 6.8.3      | 2.40+ | Ubuntu 24.10+, Fedora 41+, Arch, Debian Trixie |
| 6.6.3  | 6.6.3      | 2.35+ | Ubuntu 22.04+, Debian 12+, Fedora 36+, RHEL 9+ |
+--------+------------+-------+------------------------------------------------+
```

Choose based on your target system's glibc version:
```bash
# Check glibc version on target system
ldd --version
```

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

### Apple SDK (for macOS builds)

macOS cross-compilation requires the Xcode 12.2 SDK in the Nix store.
This SDK is not distributed with this project due to Apple's licensing terms.

Download `Xcode_12.2.xip` from Apple's website. An Apple ID is required (free to
create).
Once logged in, use the [direct
link](https://download.developer.apple.com/Developer_Tools/Xcode_12.2/Xcode_12.2.xip)
or search for [Xcode 12.2](https://developer.apple.com/download/all/?q=Xcode%2012.2).

Verify the download:
```
sha256sum Xcode_12.2.xip
28d352f8c14a43d9b8a082ac6338dc173cb153f964c6e8fb6ba389e5be528bd0  Xcode_12.2.xip
```

Extract and add to the Nix store:
```bash
nix run github:edouardparis/unxip#unxip -- Xcode_12.2.xip Xcode_12.2
cd Xcode_12.2
nix-store --add-fixed --recursive sha256 Xcode.app
```

This may take a long time. Note the output path (e.g., `/nix/store/...-Xcode.app`).

## Commands

```
Usage: ./build.sh [linux|windows|macos-arm|macos-x86|macos|all|hash|sign|verify]

  linux      Build Linux static Qt only
  windows    Build Windows static Qt only (cross-compiled)
  macos-arm  Build macOS ARM static Qt only (cross-compiled)
  macos-x86  Build macOS x86 static Qt only (cross-compiled)
  macos      Build both macOS targets
  all        Build all targets (default)
  hash       Compute hashes for existing builds in dist/
  sign       GPG sign hash manifest
  verify     Verify hashes and GPG signature
```

### Build Commands

```bash
./build.sh linux      # Build Linux only
./build.sh windows    # Build Windows only (cross-compiled)
./build.sh macos-arm  # Build macOS ARM only (cross-compiled, requires SDK)
./build.sh macos-x86  # Build macOS x86 only (cross-compiled, requires SDK)
./build.sh macos      # Build both macOS targets
./build.sh all        # Build all targets
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
├── windows/
│   ├── bin/
│   ├── include/
│   ├── lib/
│   │   ├── libQt6Core.a
│   │   ├── libQt6Gui.a
│   │   ├── libQt6Widgets.a
│   │   └── cmake/Qt6/
│   └── plugins/
│       └── platforms/  # qwindows, qdirect2d
├── macos-arm/          # macOS ARM64 (Apple Silicon)
│   ├── bin/
│   ├── include/
│   ├── lib/
│   │   └── cmake/Qt6/
│   └── plugins/
│       └── platforms/  # qcocoa
└── macos-x86/          # macOS x86_64 (Intel)
    ├── bin/
    ├── include/
    ├── lib/
    │   └── cmake/Qt6/
    └── plugins/
        └── platforms/  # qcocoa
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
| Qt Version        | See branch table above  | See branch table above  |
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
│   ├── windows.nix   # Windows cross-compile configuration
│   └── macos.nix     # macOS cross-compile configuration
├── qt-src/           # Qt source (fetched by build.sh)
│   └── qtbase/       # Patched qtbase
└── dist/             # Build output
    ├── SHA256SUMS    # Hash manifest
    ├── linux/        # Linux static Qt
    ├── windows/      # Windows static Qt
    ├── macos-arm/    # macOS ARM static Qt
    └── macos-x86/    # macOS x86 static Qt
```

## Patches Applied

The Qt source includes fixes for MinGW cross-compilation:
- `dwrite.h` include fix for `IDWriteFontFace` type (Windows only)

## License

Qt is licensed under LGPL-3.0 / GPL-3.0. See [Qt
Licensing](https://www.qt.io/licensing/).
