{
  description = "Qt 6 static build for Linux, Windows, and macOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;           # Required for Xcode SDK
          allowUnsupportedSystem = true; # Required for darwin cross-tools on Linux
        };
      };

      # Qt version configuration
      qtVersion = "6.6.3";

      # Local Qt source (use --impure flag to access non-git-tracked path)
      # QT_SRC_PATH env var set by build.sh, fallback to ./qt-src/qtbase
      qtSrcPath = builtins.getEnv "QT_SRC_PATH";
      qt6Source = builtins.path {
        path = if qtSrcPath != "" then /. + qtSrcPath else ./qt-src/qtbase;
        name = "qtbase-source";
      };

      # Linux build from local fork
      qt6Linux = pkgs.callPackage ./nix/linux.nix {
        inherit qt6Source qtVersion;
      };

      # Windows build from local fork
      qt6Windows = pkgs.callPackage ./nix/windows.nix {
        inherit qt6Source qtVersion;
        qt6HostTools = qt6Linux;
        mingwPkgs = pkgs.pkgsCross.mingwW64;
      };

      # macOS cross-compilation (aarch64 - Apple Silicon)
      # Requires Xcode 12.2 SDK in nix store (see README)
      # Uses clang + lld for cross-compilation
      qt6MacosArm = pkgs.callPackage ./nix/macos.nix {
        inherit qt6Source qtVersion;
        qt6HostTools = qt6Linux;
        targetArch = "aarch64";
        xcode = pkgs.darwin.xcode_12_2;
        llvmPackages = pkgs.llvmPackages_18;
      };

      # macOS cross-compilation (x86_64 - Intel)
      # Requires Xcode 12.2 SDK in nix store (see README)
      # Uses clang + lld for cross-compilation
      qt6MacosX86 = pkgs.callPackage ./nix/macos.nix {
        inherit qt6Source qtVersion;
        qt6HostTools = qt6Linux;
        targetArch = "x86_64";
        xcode = pkgs.darwin.xcode_12_2;
        llvmPackages = pkgs.llvmPackages_18;
      };

    in
    {
      packages.${system} = {
        linux = qt6Linux;
        windows = qt6Windows;
        aarch64-apple-darwin = qt6MacosArm;
        x86_64-apple-darwin = qt6MacosX86;
        default = qt6Linux;
      };

      devShells.${system}.default = pkgs.mkShell {
        name = "qt6-static-dev";

        buildInputs = [
          qt6Linux
          pkgs.cmake
          pkgs.ninja
          pkgs.pkg-config
        ];

        shellHook = ''
          echo "Qt 6 Static Development Shell"
          echo "=============================="
          echo "Qt Version: ${qtVersion}"
          echo "Linux Qt: available at ${qt6Linux}"
          echo ""
          echo "Build commands:"
          echo "  nix build .#linux               - Build Linux static Qt"
          echo "  nix build .#windows             - Build Windows static Qt"
          echo "  nix build .#aarch64-apple-darwin - Build macOS ARM static Qt"
          echo "  nix build .#x86_64-apple-darwin  - Build macOS x86 static Qt"
          echo ""
          export QT_DIR="${qt6Linux}"
          export CMAKE_PREFIX_PATH="${qt6Linux}"
        '';
      };

      # Expose for easy access
      inherit qt6Source;
    };
}
