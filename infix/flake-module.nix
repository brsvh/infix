{
  inputs,
  ...
}:
let
  infix-lib = import ./lib {
    inherit (inputs.nixpkgs)
      lib
      ;
  };
in
{
  flake = {
    lib = infix-lib;
  };

  systems = [ ];
}
