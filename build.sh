#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

TARGET="${1:-all}"

echo "=== Qt6 Static Build ==="

# ---- Phase 1: Fetch Qt source (only if needed) ----
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

# Set absolute path for nix flake
export QT_SRC_PATH="$SCRIPT_DIR/qt-src/qtbase"
echo "Using Qt source: $QT_SRC_PATH"

# ---- Phase 2: Build functions ----
compute_hashes() {
    echo ""
    echo "=== Computing Build Hashes ==="

    local manifest="dist/SHA256SUMS"
    > "$manifest"  # Clear/create manifest

    # Compute hashes for each target
    for target in linux windows; do
        local dir="dist/$target"
        if [ -d "$dir" ]; then
            echo "Hashing $target..."
            (cd dist && find "$target" -type f -exec sha256sum {} \; | sort -k2) >> "$manifest"
        fi
    done

    echo ""
    echo "Manifest: $manifest"

    # Print easy-to-copy hashes
    echo ""
    echo "=== Target Hashes ==="
    for target in linux windows; do
        if grep -q "^[a-f0-9]* *$target/" "$manifest" 2>/dev/null; then
            TARGET_HASH=$(grep "^[a-f0-9]* *$target/" "$manifest" | sha256sum | cut -d' ' -f1)
            echo "$target $TARGET_HASH"
        fi
    done
}

sign_hashes() {
    local manifest="dist/SHA256SUMS"

    if [ ! -f "$manifest" ]; then
        echo "Error: $manifest not found. Run './build.sh hash' first."
        exit 1
    fi

    echo ""
    echo "=== Signing manifest ==="

    gpg --armor --detach-sign --output "$manifest.sig" "$manifest"

    echo "Signature: $manifest.sig"
}

verify_hashes() {
    local manifest="dist/SHA256SUMS"
    local sig="$manifest.sig"

    echo ""
    echo "=== Verifying Build ==="

    # Verify GPG signature if present
    if [ -f "$sig" ]; then
        echo "Verifying GPG signature..."
        if gpg --verify "$sig" "$manifest" 2>/dev/null; then
            echo "Signature: VALID"
        else
            echo "Signature: INVALID"
            exit 1
        fi
    else
        echo "Signature: not found (skipping)"
    fi

    # Verify file hashes
    echo ""
    echo "Verifying file hashes..."
    if (cd dist && sha256sum -c SHA256SUMS); then
        echo ""
        echo "All hashes: VALID"
    else
        echo ""
        echo "Hash verification: FAILED"
        exit 1
    fi
}

build_linux() {
    echo ""
    echo "=== Building Linux static Qt ==="
    nix build .#linux -o result-linux --impure

    echo "Packaging to dist/linux/..."
    rm -rf dist/linux
    mkdir -p dist/linux
    cp -rL result-linux/* dist/linux/

    echo "Linux build complete: dist/linux/"
}

build_windows() {
    echo ""
    echo "=== Building Windows static Qt ==="
    nix build .#windows -o result-windows --impure

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
        compute_hashes
        ;;
    windows)
        build_windows
        compute_hashes
        ;;
    all)
        build_linux
        build_windows
        compute_hashes
        ;;
    hash)
        # Standalone hash command - process existing dist/*
        compute_hashes
        ;;
    sign)
        # Sign the manifest
        sign_hashes
        ;;
    verify)
        # Verify hashes and signature
        verify_hashes
        ;;
    *)
        echo "Usage: $0 [linux|windows|all|hash|sign|verify]"
        echo ""
        echo "  linux    Build Linux static Qt only"
        echo "  windows  Build Windows static Qt only (cross-compiled)"
        echo "  all      Build both targets (default)"
        echo "  hash     Compute hashes for existing builds in dist/"
        echo "  sign     GPG sign hash manifest"
        echo "  verify   Verify hashes and GPG signature"
        exit 1
        ;;
esac

echo ""
echo "=== Build complete ==="
echo ""
echo "Use in CMake projects:"
echo "  cmake -DCMAKE_PREFIX_PATH=\$PWD/dist/linux .."
echo "  cmake -DCMAKE_PREFIX_PATH=\$PWD/dist/windows .."
