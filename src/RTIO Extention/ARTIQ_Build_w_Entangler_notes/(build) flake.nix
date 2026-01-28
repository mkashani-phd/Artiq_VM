{
  inputs.artiq.url = "git+https://github.com/m-labs/artiq.git?ref=release-7";
  inputs.extrapkg.url = "git+https://git.m-labs.hk/M-Labs/artiq-extrapkg.git?ref=release-7";
  inputs.extrapkg.inputs.artiq.follows = "artiq";
  inputs.zynq-rs.url = git+https://git.m-labs.hk/m-labs/zynq-rs;
  inputs.zynq-rs.inputs.nixpkgs.follows = "artiq/nixpkgs";

  outputs = { self, artiq, extrapkg, zynq-rs }:
    let
      pkgs = artiq.inputs.nixpkgs.legacyPackages.x86_64-linux;
      aqmain = artiq.packages.x86_64-linux;
      aqextra = extrapkg.packages.x86_64-linux;

      rust = zynq-rs.rust;
      # rustPlatform = zynq-rs.rustPlatform;

      dynaconf = pkgs.python3Packages.buildPythonPackage rec {
        pname = "dynaconf";
        version = "3.1.7";
        src = pkgs.python3Packages.fetchPypi {
          inherit pname version;
          sha256 = "sha256-6dgLRrpNk3Ly9AyBJZTJY/dBeBQMC1luV/KIEAH8TTU=";
        };
        propagatedBuildInputs = with pkgs.python3Packages; [
          click
          python-box
          python-dotenv
          toml
        ];
        doCheck = false;
      };

      entangler = pkgs.python3Packages.buildPythonPackage rec {
        pname = "entangler";
        version = "1.2.0.post0";
        pyproject = true;
        buildGateware = true;
        src = pkgs.fetchFromGitHub {
          owner = "drewrisinger";
          repo = "entangler-core";
          rev = "v${version}";
          sha256 = "sha256-n0vRqtX0x2enO1IuBYyKSbcGXBxa7fTy59NH6sYRa3A=";
        };
        buildInputs = with pkgs.python3Packages; [ pytestrunner ];
        propagatedBuildInputs = [ 
          pkgs.python3Packages.numpy 
          aqmain.artiq
          dynaconf
        ] ++ pkgs.lib.optionals buildGateware [
          pkgs.python3Packages.jsonschema
          pkgs.python3Packages.mergedeep
          aqmain.migen
          aqmain.misoc
        ];
        doCheck = buildGateware; 
        checkInputs = [ pkgs.python3Packages.pytestCheckHook ];
        pytestFlagsArray = [ "-m 'not slow'" ];
        pythonImportsCheck = [ pname "${pname}.driver" ]
          ++ pkgs.lib.optionals buildGateware [ "${pname}.kasli_generic" "${pname}.core" "${pname}.phy" ];
      };
    in {
      # packages.x86_64-linux.entangler = entangler; # uncomment this if you want the standalone entangler package
      defaultPackage.x86_64-linux = pkgs.buildEnv {
        name = "artiq-env";
        paths = [
          # ========================================
          # EDIT BELOW
          # ========================================
          (pkgs.python3.withPackages(ps: [
            # List desired Python packages here.
            aqmain.artiq
            entangler
            #ps.paramiko  # needed if and only if flashing boards remotely (artiq_flash -H)
            #aqextra.flake8-artiq

            # The NixOS package collection contains many other packages that you may find
            # interesting. Here are some examples:
            ps.pandas
            ps.numpy
            ps.scipy
            ps.numba
            ps.matplotlib
            # or if you need Qt (will recompile):
            #(ps.matplotlib.override { enableQt = true; })
            #ps.bokeh
            #ps.cirq
            #ps.qiskit
          ]))
          #aqextra.korad_ka3005p
          #aqextra.novatech409b
          # List desired non-Python packages here
          aqmain.openocd-bscanspi  # needed if and only if flashing boards

          # Vivado
          aqmain.vivado
          aqmain.vivadoEnv

          # Cargo/rust dependencies?
          pkgs.cargo-xbuild
          rust          

          # LLVM/clang
          pkgs.llvmPackages_11.clang-unwrapped
          pkgs.llvm_11
          pkgs.lld_11

          # Other potentially interesting packages from the NixOS package collection:
          #pkgs.gtkwave
          #pkgs.spyder
          #pkgs.R
          #pkgs.julia
          # ========================================
          # EDIT ABOVE
          # ========================================
        ];
      };
    };
  nixConfig = {  # work around https://urldefense.com/v3/__https://github.com/NixOS/nix/issues/6771__;!!DZ3fjg!4YmaK8HagrzH09ANhIQPRyD5pfkFPBKzC3vnj3Q8KKyKIgBU0Yb31t_vWoZAgwRjHsfHZNFKTnBEye2NgdxYXA$ 
    extra-trusted-public-keys = "nixbld.m-labs.hk-1:5aSRVA5b320xbNvu30tqxVPXpld73bhtOeH6uAjRyHc=";
    extra-substituters = "https://urldefense.com/v3/__https://nixbld.m-labs.hk__;!!DZ3fjg!4YmaK8HagrzH09ANhIQPRyD5pfkFPBKzC3vnj3Q8KKyKIgBU0Yb31t_vWoZAgwRjHsfHZNFKTnBEye12B_2B8Q$ ";
  };
}
