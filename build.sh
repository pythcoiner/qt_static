#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

TARGET="${1:-all}"

echo "=== Qt6 Static Build ==="

# ---- Phase 1: Fetch Qt source ----
QT_BRANCH="qt_static_6.8.3"
QT_REPO="https://github.com/pythcoiner/qt5.git"

if [ ! -d "qt-src" ]; then
    echo "Cloning Qt source..."
    git clone --depth 1 -b "$QT_BRANCH" "$QT_REPO" qt-src
    cd qt-src
    git submodule update --init --progress qtbase
    cd "$SCRIPT_DIR"
else
    cd qt-src

    # Check if we need to update the main repo
    git fetch --depth 1 origin "$QT_BRANCH"
    LOCAL_COMMIT=$(git rev-parse HEAD)
    REMOTE_COMMIT=$(git rev-parse FETCH_HEAD)

    if [ "$LOCAL_COMMIT" != "$REMOTE_COMMIT" ]; then
        echo "Updating Qt source..."
        git checkout "$QT_BRANCH"
        git pull origin "$QT_BRANCH"
    else
        echo "Qt source is up to date."
    fi

    # Check if qtbase submodule needs initialization or update
    if [ ! -d "qtbase/.git" ] && [ ! -f "qtbase/.git" ]; then
        echo "Initializing qtbase submodule..."
        git submodule update --init --progress qtbase
    else
        # Check if submodule needs update
        EXPECTED_COMMIT=$(git ls-tree HEAD qtbase | awk '{print $3}')
        ACTUAL_COMMIT=$(git -C qtbase rev-parse HEAD 2>/dev/null || echo "none")

        if [ "$EXPECTED_COMMIT" != "$ACTUAL_COMMIT" ]; then
            echo "Updating qtbase submodule..."
            git submodule update --progress qtbase
        else
            echo "qtbase submodule is up to date."
        fi
    fi

    cd "$SCRIPT_DIR"
fi

# ---- Phase 2: Build functions ----
build_linux() {
    echo ""
    echo "=== Building Linux static Qt ==="
    nix build .#linux -o result-linux

    echo "Packaging to dist/linux/..."
    rm -rf dist/linux
    mkdir -p dist/linux
    cp -rL result-linux/* dist/linux/

    echo "Linux build complete: dist/linux/"
}

build_windows() {
    echo ""
    echo "=== Building Windows static Qt ==="
    nix build .#windows -o result-windows

    echo "Packaging to dist/windows/..."
    rm -rf dist/windows
    mkdir -p dist/windows
    cp -rL result-windows/* dist/windows/

    echo "Windows build complete: dist/windows/"
}

# ---- Phase 3: Target selection ----
case "$TARGET" in
    linux)
        build_linux
        ;;
    windows)
        build_windows
        ;;
    all)
        build_linux
        build_windows
        ;;
    *)
        echo "Usage: $0 [linux|windows|all]"
        echo ""
        echo "  linux    Build Linux static Qt only"
        echo "  windows  Build Windows static Qt only (cross-compiled)"
        echo "  all      Build both targets (default)"
        exit 1
        ;;
esac

echo ""
echo "=== Build complete ==="
echo ""
echo "Use in CMake projects:"
echo "  cmake -DCMAKE_PREFIX_PATH=\$PWD/dist/linux .."
echo "  cmake -DCMAKE_PREFIX_PATH=\$PWD/dist/windows .."
