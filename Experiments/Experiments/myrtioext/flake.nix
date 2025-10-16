{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    artiq-zynq.url = "git+https://git.m-labs.hk/m-labs/artiq-zynq?ref=release-7";

    # If you did Option A (no inner flake), keep this path as-is:
    myrtioext.url = "path:./Experiments/myrtioext";

    # If you did Option B (moved it out), use e.g.:
    # myrtioext.url = "path:../myrtioext-src";
  };

  outputs = { self, nixpkgs, artiq-zynq, myrtioext }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };

    # Build your Python package from the source tree
    myrtioextPkg = pkgs.python3Packages.buildPythonPackage {
      pname = "myrtioext";
      version = "0.1.0";
      src = myrtioext;  # path input; not a flake now
      format = "pyproject";
      nativeBuildInputs = with pkgs.python3Packages; [ setuptools wheel ];
    };

    target   = "kasli_soc";
    variant  = "standalone";
    jsonPath = /home/jrydberg/Documents/Projects/Artiq_envs/defult/kasli-soc-standalone_node1_with_edgecounters_en.json;

    # Call upstream. This returns a set with hyphenated attrs.
    pkgSet  = artiq-zynq.makeArtiqZynqPackage { inherit target variant; json = jsonPath; };
    sdName  = "${target}-${variant}-sd";
    sdImage = builtins.getAttr sdName pkgSet;
  in {
    # Build with: nix build .#sd --print-build-logs --impure
    packages.${system}.sd = sdImage;

    # Dev shell just to sanity-check your package imports
    devShells.${system}.default = pkgs.mkShell {
      packages = [ pkgs.python3 myrtioextPkg ];
      shellHook = ''
        echo "Testing myrtioext import..."
        python - <<'PY'
try:
    import myrtioext; print("OK:", myrtioext.__file__)
except Exception as e:
    print("Import failed:", e)
PY
      '';
    };
  };
}
