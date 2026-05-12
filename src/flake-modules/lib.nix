{
  lib,
  ...
}:
let
  inherit (lib)
    mkOption
    types
    ;
in
{
  options = {
    flake = {
      lib = mkOption {
        default = { };

        description = ''
          An attribute set of library functions.
        '';

        type = with types; lazyAttrsOf raw;
      };
    };
  };
}
