{
  description = "Qt 6 static build for Linux and Windows";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };

      # Qt version configuration
      qtVersion = "6.8.3";

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

    in
    {
      packages.${system} = {
        linux = qt6Linux;
        windows = qt6Windows;
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
          echo "  nix build .#linux    - Build Linux static Qt"
          echo "  nix build .#windows  - Build Windows static Qt"
          echo ""
          export QT_DIR="${qt6Linux}"
          export CMAKE_PREFIX_PATH="${qt6Linux}"
        '';
      };

      # Expose for easy access
      inherit qt6Source;
    };
}
