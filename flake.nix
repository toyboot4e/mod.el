{
  description = "mod.el — defmod, a package-configuration macro that only schedules";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { self, nixpkgs }:
    let
      forAllSystems =
        f: nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (system: f nixpkgs.legacyPackages.${system});
    in
    {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [
            (pkgs.emacs.pkgs.withPackages (epkgs: [ epkgs.package-lint ]))
            pkgs.just
          ];
        };
      });
    };
}
