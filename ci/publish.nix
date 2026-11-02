{
  cache,
  hci-effects,
  name,
  outputs,
  pkgs,
  rev,
}:
let
  inherit (pkgs.lib)
    attrValues
    toJSON
    ;

  request =
    pkgs.writeText "publish-request.json"
      (toJSON {
        inherit
          cache
          name
          rev
          ;

        # Keep the output contexts so the Effect depends on every output.
        roots = map toString (attrValues outputs);
      });
in
hci-effects.mkEffect {
  name = "publish-${name}";
  dontUnpack = true;

  inputs = with pkgs; [
    nix
    nodejs
  ];

  secretsMap = {
    git = {
      type = "GitToken";
    };

    public-cache = "public-cache-upload";
  };

  NIX_CONFIG = ''
    experimental-features = nix-command
  '';

  effectScript = ''
    node ${./publish.mjs} ${request}
  '';
}
