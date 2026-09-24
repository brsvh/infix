{
  infix,
  inputs,
  lib,
  projectRoot,
  self,
  ...
}:
let
  inherit (lib)
    makeBinPath
    mapAttrs
    ;

  inherit (inputs)
    nixpkgs
    ;
in
{
  perSystem =
    {
      pkgs,
      system,
      ...
    }:
    let
      inherit (pkgs)
        treefmt
        writeShellScriptBin
        ;
    in
    rec {
      _module = {
        args = {
          pkgs = import nixpkgs {
            inherit
              system
              ;

            overlays = [
              self.overlays.default
            ];
          };
        };
      };

      devShells = mapAttrs (
        _: devShell:
        import devShell {
          inherit
            infix
            inputs
            lib
            pkgs
            projectRoot
            ;
        }
      ) (infix.devShells or { });

      formatter =
        let
          desc = devShells.default.passthru;

          config = desc.files.treefmt;

          path = makeBinPath desc.dependencies.treefmt.packages;
        in
        writeShellScriptBin "treefmt" ''
          set -euo pipefail
          export PATH=${path}
          exec ${treefmt}/bin/treefmt \
            --config-file=${config} \
            --tree-root-file=flake.nix \
            "$@"
        '';
    };

  systems = [
    "x86_64-linux"
  ];
}
