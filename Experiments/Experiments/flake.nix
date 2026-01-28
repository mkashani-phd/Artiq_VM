{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    artiq-zynq.url = "git+https://git.m-labs.hk/m-labs/artiq-zynq?ref=release-7";
    myrtioext.url = "path:./Experiments/myrtioext";
  };

  outputs = { self, nixpkgs, artiq-zynq, myrtioext }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };

    myrtioextPkg = pkgs.python3Packages.buildPythonPackage {
      pname = "myrtioext";
      version = "0.1.0";
      src = myrtioext;
      format = "pyproject";
      nativeBuildInputs = with pkgs.python3Packages; [ setuptools wheel ];
      propagatedBuildInputs = [ ];
    };

    target   = "kasli_soc";
    variant  = "standalone";
    # TODO: change this JSON path to your actual kasli-soc JSON
    jsonPath = /home/jrydberg/Documents/Projects/Artiq_envs/defult/kasli-soc-standalone_node1_with_edgecounters_en.json;

    pkgSet  = artiq-zynq.makeArtiqZynqPackage { inherit target variant; json = jsonPath; };
    sdName  = "${target}-${variant}-sd";
    sdImage = builtins.getAttr sdName pkgSet;
  in {
    packages.${system}.sd = sdImage;

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
