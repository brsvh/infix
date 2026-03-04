{
  flake-parts-lib,
  lib,
  inputs,
  ...
}:
let
  inherit (flake-parts-lib)
    mkPerSystemOption
    ;

  inherit (lib)
    attrValues
    flatten
    hasAttr
    map
    mapAttrs
    mapAttrs'
    mkOption
    nameValuePair
    types
    ;

  hasInput =
    input:
    if hasAttr input inputs then
      inputs.${input}
    else
      throw ''
        ${input} input not found, please add a ${input} input to your flake.
      '';

  devshell = hasInput "devshell";

  nixago = hasInput "nixago";
in
{
  options = {
    perSystem = mkPerSystemOption (
      {
        config,
        lib,
        pkgs,
        system,
        ...
      }:
      let
        # Import nixago engine registry for this evaluation context.
        # Engines implement the rendering back-end for requests.  We
        # import it explicitly so that requests can reference engines
        # without requiring users to wire them by hand.
        nixagoEngines =
          import "${nixago}/engines/default.nix"
            {
              inherit
                lib
                pkgs
                ;
            };

        # Import nixago request module, this module defines the option
        # schema for a single nixago request (what to generate, where
        # to link it, and how to manage it).  It is module-shaped, so
        # we can embed it as a sub-module under our own option tree
        # and reuse nixago validation and defaults.
        nixagoRequests =
          import "${nixago}/modules/request.nix"
            {
              inherit
                config
                lib
                ;

              engines = nixagoEngines;
            };

        # Resolve nixago make entry-point for the current system, make
        # returns an attribute set that includes configFile (the
        # derivation) and shellHook (the activation snippet that
        # links/updates the generated file when entering a devShell).
        mkNixago = nixago.lib.${system}.make;

        submodules =
          # Start from devshell upstream module set, devshell models
          # devShells via the Nix module system; importing its module
          # list gives us the canonical option surface (packages, env,
          # commands, startup hooks, etc.), and we then extend it with
          # our custom integration below.
          (import "${devshell}/modules/modules.nix" {
            inherit
              lib
              pkgs
              ;
          })
          ++ [
            (
              {
                config,
                ...
              }:
              {
                options = {
                  ago = mkOption {
                    default = { };

                    description = ''
                      A list of nixago configurations.
                    '';

                    type =
                      with types;
                      lazyAttrsOf (submoduleWith {
                        modules = [
                          # Reuse nixago request option schema
                          # verbatim, this provides the standard
                          # nixago knobs under each entry in ago
                          # name-space.
                          (
                            {
                              ...
                            }:
                            nixagoRequests
                          )

                          # Allow each request to declare extra
                          # runtime dependencies that should be
                          # present in the devshell where the hook
                          # runs.  This is intentionally shell-level
                          # dependency tracking: nixago itself can
                          # generate the file, but auxiliary tooling
                          # often needs to be available in the same
                          # environment.
                          (
                            {
                              ...
                            }:
                            {
                              options = {
                                packages = mkOption {
                                  default = [ ];

                                  description = ''
                                    Dependencies of this request.
                                  '';

                                  type = listOf package;
                                };
                              };
                            }
                          )
                        ];
                      });
                  };

                  agoFiles = mkOption {
                    default = { };
                    type = with types; attrsOf anything;
                    description = ''
                      Derived nixago artifacts.
                    '';
                  };
                };

                config =
                  let
                    ago' = mapAttrs (_: v: mkNixago v) config.ago;
                  in
                  {
                    agoFiles = mapAttrs (_: v: v.configFile) ago';

                    # Materialize ago name-space into devshell
                    # configuration.
                    #
                    # - packages is the union of all request-level
                    #   packages, ensuring request hooks can rely on
                    #   their declared tools being available.
                    # - startup registers one startup step per
                    #   request; each step is a nixago-generated
                    #   shellHook that links the generated config into
                    #   the working tree (typically under $PRJ_ROOT
                    #   when set).
                    devshell = {
                      packages =
                        let
                          liftPackages = attrs: attrs.packages;
                        in
                        flatten (
                          map liftPackages (attrValues config.ago)
                        );

                      # Convert each request into a named startup step
                      # so that entering the devshell triggers file
                      # generation/linking, We keep the attribute name
                      # as the step name to preserve a stable identity
                      # for ordering and debugging.
                      startup = mapAttrs (n: _: {
                        text = ago'.${n}.shellHook;
                      }) config.ago;
                    };
                  };
              }
            )
          ];
      in
      {
        options = {
          devshells = mkOption {
            default = { };

            description = ''
              Configure devshells with flake-parts.

              Not to be confused with `devShells`, with a capital S.  Yes, this
              is unfortunate.

              Each devshell will also configure an equivalent `devShells`.

              Used to define devshells, not to be confused with `devShells`
            '';

            type =
              with types;
              lazyAttrsOf (submoduleWith {
                modules = submodules;
              });
          };
        };

        config = {
          # Bridge devshells.<name> (module-shaped) into
          # devShells.<name> (standard flake output).  devshell
          # exposes the final derivation as devshell.shell; flake
          # consumers expect devShells.<system>.<name> to be a
          # derivation.
          devShells =
            let
              liftShell = attrs: attrs.devshell.shell;
            in
            mapAttrs (name: liftShell) config.devshells;
        };
      }
    );
  };
}
