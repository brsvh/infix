{
  inputs,
  self,
  ...
}:
{
  perSystem =
    {
      pkgs,
      ...
    }:
    let
      inherit (pkgs)
        nix-unit
        runCommand
        ;

      test =
        runCommand "test"
          {
            nativeBuildInputs = [
              nix-unit
            ];
          }
          ''
            export HOME="$(realpath .)"
            mkdir -p "$HOME/gcroots"
            nix-unit \
              --eval-store "$HOME" \
              --extra-experimental-features flakes \
              --gc-roots-dir "$HOME/gcroots" \
              --override-input nixpkgs ${inputs.nixpkgs} \
              --show-trace \
              --flake ${self}#lib.__tests
            touch "$out"
          '';
    in
    {
      checks = {
        inherit
          test
          ;
      };
    };
}
