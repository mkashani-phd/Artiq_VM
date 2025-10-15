{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";

    # Upstream ARTIQ-Zynq (release-7)
    artiq-zynq.url = "git+https://git.m-labs.hk/m-labs/artiq-zynq?ref=release-7";
    artiq-zynq.inputs.nixpkgs.follows = "nixpkgs";

    # Your local myrtioext repo (adjust path)
    myrtioext.url = "path:/home/jrydberg/Documents/Projects/Artiq_envs/defult/Artiq_VM/Experiments/myrtioext";
  };

  outputs = { self, nixpkgs, artiq-zynq, myrtioext }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };

    # Build your Python package (just the derivation; we’re not forcing it into upstream’s env yet)
    myrtioextPkg = pkgs.python3Packages.buildPythonPackage {
      pname = "myrtioext";
      version = "0.1.0";
      src = myrtioext;
      format = "pyproject";
      nativeBuildInputs = with pkgs.python3Packages; [ setuptools wheel ];
      propagatedBuildInputs = [ ];
    };

    # Choose target/variant/json (adjust to your JSON path)
    target   = "kasli_soc";
    variant  = "standalone";
    jsonPath = /home/jrydberg/Documents/Projects/Artiq_envs/defult/kasli-soc-standalone_node1_with_edgecounters_en.json;

    # Call upstream helper and safely select the SD image attr (hyphenated)
    pkgSet  = artiq-zynq.makeArtiqZynqPackage { inherit target variant; json = jsonPath; };
    sdName  = "${target}-${variant}-sd";
    sdImage = builtins.getAttr sdName pkgSet;
  in {
    # Build with: nix build .#sd --print-build-logs --impure
    packages.${system}.sd = sdImage;

    # (Optional) dev shell to sanity-check your myrtioext package builds & imports
    devShells.${system}.default = pkgs.mkShell {
      packages = [ pkgs.python3 myrtioextPkg ];
      shellHook = ''
        echo "Dev shell: testing myrtioext import"
        python - <<'PY'
try:
    import myrtioext; print("myrtioext OK:", myrtioext.__file__)
except Exception as e:
    print("Import failed:", e)
PY
      '';
    };
  };
}
