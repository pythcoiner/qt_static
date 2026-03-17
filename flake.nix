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

      # Local qtsvg source
      qtSvgSrcPath = builtins.getEnv "QT_SVG_SRC_PATH";
      qtSvgSource = builtins.path {
        path = if qtSvgSrcPath != "" then /. + qtSvgSrcPath else ./qt-src/qtsvg;
        name = "qtsvg-source";
      };

      # ---- qtbase builds ----

      qt6Linux = pkgs.callPackage ./nix/linux.nix {
        inherit qt6Source qtVersion;
      };

      qt6Windows = pkgs.callPackage ./nix/windows.nix {
        inherit qt6Source qtVersion;
        qt6HostTools = qt6Linux;
        mingwPkgs = pkgs.pkgsCross.mingwW64;
      };

      qt6MacosArm = pkgs.callPackage ./nix/macos.nix {
        inherit qt6Source qtVersion;
        qt6HostTools = qt6Linux;
        targetArch = "aarch64";
        xcode = pkgs.darwin.xcode_12_2;
        llvmPackages = pkgs.llvmPackages_18;
      };

      qt6MacosX86 = pkgs.callPackage ./nix/macos.nix {
        inherit qt6Source qtVersion;
        qt6HostTools = qt6Linux;
        targetArch = "x86_64";
        xcode = pkgs.darwin.xcode_12_2;
        llvmPackages = pkgs.llvmPackages_18;
      };

      # ---- qtsvg builds ----

      qt6SvgLinux = pkgs.callPackage ./nix/qtsvg-linux.nix {
        inherit qtSvgSource qtVersion qt6Linux;
      };

      qt6SvgWindows = pkgs.callPackage ./nix/qtsvg-windows.nix {
        inherit qtSvgSource qtVersion qt6Linux;
        qt6Windows = qt6Windows;
        mingwPkgs = pkgs.pkgsCross.mingwW64;
      };

      qt6SvgMacosArm = pkgs.callPackage ./nix/qtsvg-macos.nix {
        inherit qtSvgSource qtVersion qt6Linux;
        qt6Macos = qt6MacosArm;
        targetArch = "aarch64";
        xcode = pkgs.darwin.xcode_12_2;
        llvmPackages = pkgs.llvmPackages_18;
      };

      qt6SvgMacosX86 = pkgs.callPackage ./nix/qtsvg-macos.nix {
        inherit qtSvgSource qtVersion qt6Linux;
        qt6Macos = qt6MacosX86;
        targetArch = "x86_64";
        xcode = pkgs.darwin.xcode_12_2;
        llvmPackages = pkgs.llvmPackages_18;
      };

      # ---- combined (qtbase + qtsvg) ----

      combinedLinux = pkgs.callPackage ./nix/combine.nix {
        qtbase = qt6Linux;
        qtsvg = qt6SvgLinux;
        name = "qt6-static-linux";
      };

      combinedWindows = pkgs.callPackage ./nix/combine.nix {
        qtbase = qt6Windows;
        qtsvg = qt6SvgWindows;
        name = "qt6-static-windows";
      };

      combinedMacosArm = pkgs.callPackage ./nix/combine.nix {
        qtbase = qt6MacosArm;
        qtsvg = qt6SvgMacosArm;
        name = "qt6-static-macos-aarch64";
      };

      combinedMacosX86 = pkgs.callPackage ./nix/combine.nix {
        qtbase = qt6MacosX86;
        qtsvg = qt6SvgMacosX86;
        name = "qt6-static-macos-x86_64";
      };

    in
    {
      packages.${system} = {
        # Combined packages (qtbase + qtsvg) - the default
        linux = combinedLinux;
        windows = combinedWindows;
        aarch64-apple-darwin = combinedMacosArm;
        x86_64-apple-darwin = combinedMacosX86;
        default = combinedLinux;

        # Individual qtbase-only packages
        qtbase-linux = qt6Linux;
        qtbase-windows = qt6Windows;
        qtbase-macos-arm = qt6MacosArm;
        qtbase-macos-x86 = qt6MacosX86;

        # Individual qtsvg-only packages
        qtsvg-linux = qt6SvgLinux;
        qtsvg-windows = qt6SvgWindows;
        qtsvg-macos-arm = qt6SvgMacosArm;
        qtsvg-macos-x86 = qt6SvgMacosX86;
      };

      devShells.${system}.default = pkgs.mkShell {
        name = "qt6-static-dev";

        buildInputs = [
          combinedLinux
          pkgs.cmake
          pkgs.ninja
          pkgs.pkg-config
        ];

        shellHook = ''
          echo "Qt 6 Static Development Shell"
          echo "=============================="
          echo "Qt Version: ${qtVersion}"
          echo "Linux Qt: available at ${combinedLinux}"
          echo ""
          echo "Build commands:"
          echo "  nix build .#linux               - Build Linux static Qt (qtbase + qtsvg)"
          echo "  nix build .#windows             - Build Windows static Qt (qtbase + qtsvg)"
          echo "  nix build .#aarch64-apple-darwin - Build macOS ARM static Qt (qtbase + qtsvg)"
          echo "  nix build .#x86_64-apple-darwin  - Build macOS x86 static Qt (qtbase + qtsvg)"
          echo ""
          echo "  nix build .#qtbase-linux         - Build Linux qtbase only"
          echo "  nix build .#qtsvg-linux          - Build Linux qtsvg only"
          echo ""
          export QT_DIR="${combinedLinux}"
          export CMAKE_PREFIX_PATH="${combinedLinux}"
        '';
      };

      # Expose for easy access
      inherit qt6Source qtSvgSource;
    };
}
