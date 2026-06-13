{
  description = "defmod.el — a package-configuration macro that only schedules";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      treefmt-nix,
    }:
    let
      forAllSystems =
        f:
        nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (system: f nixpkgs.legacyPackages.${system});
      emacsFor = pkgs: pkgs.emacs.pkgs.withPackages (epkgs: [ epkgs.package-lint ]);

      treefmtFor = forAllSystems (
        pkgs:
        treefmt-nix.lib.evalModule pkgs {
          projectRootFile = "flake.nix";
          programs.nixfmt.enable = true;
        }
      );
    in
    {
      checks = forAllSystems (pkgs: {
        treefmt = treefmtFor.${pkgs.system}.config.build.check self;

        zizmor = pkgs.runCommand "zizmor-check" { nativeBuildInputs = [ pkgs.zizmor ]; } ''
          cd ${self}
          zizmor --offline . && touch "$out"
        '';

        ci =
          pkgs.runCommand "defmod-ci"
            {
              nativeBuildInputs = [
                (emacsFor pkgs)
                pkgs.just
              ];
            }
            ''
              cp -r ${self} build && chmod -R u+w build && cd build
              export HOME="$TMPDIR"
              just ci
              touch "$out"
            '';
      });

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [
            (emacsFor pkgs)
            pkgs.just
            pkgs.pinact
            pkgs.zizmor
          ];
        };
      });

      formatter = forAllSystems (pkgs: treefmtFor.${pkgs.system}.config.build.wrapper);
    };
}
