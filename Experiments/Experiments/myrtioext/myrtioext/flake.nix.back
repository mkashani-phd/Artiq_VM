{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    artiq.url = "git+https://github.com/m-labs/artiq.git?ref=release-7";
    extrapkg.url = "git+https://git.m-labs.hk/M-Labs/artiq-extrapkg.git?ref=release-7";
    extrapkg.inputs.artiq.follows = "artiq";
  };

  outputs = { self, nixpkgs, artiq, extrapkg }:
  let
    system = "x86_64-linux";
    pkgs = artiq.inputs.nixpkgs.legacyPackages.${system};
    python = pkgs.python3;

    # ARTIQ python packages from the ARTiq flake
    artiqPkgs = artiq.packages.${system};
    extraPkgs = extrapkg.packages.${system};

    # Build your local Python package with setuptools/pyproject
    myrtioext = pkgs.python3Packages.buildPythonPackage {
      pname = "myrtioext";
      version = "0.1.0";
      src = ./.;
      format = "pyproject";
      nativeBuildInputs = with pkgs.python3Packages; [ setuptools wheel ];
      propagatedBuildInputs = [ ];
    };

    # A Python environment that includes ARTIQ + your package
    pyEnv = python.withPackages (ps: [
      myrtioext
      artiqPkgs.artiq
      # optional extras (remove if you don't need them):
      # artiqPkgs.artiq-full
      # extraPkgs.artiq-examples
    ]);
  in {
    # `nix build` will build your python package
    packages.${system}.default = myrtioext;

    # `nix develop` gives you a shell with ARTIQ + your package on PYTHONPATH
    devShells.${system}.default = pkgs.mkShell {
      packages = [
        pyEnv
        pkgs.git
      ];
      shellHook = ''
        echo "Dev shell ready. Python with ARTIQ + myrtioext is on PATH."
        echo "Try: python -c 'import myrtioext, artiq; print(myrtioext.__version__)'"
      '';
    };
  };
}
