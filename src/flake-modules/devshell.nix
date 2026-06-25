{
  flake-parts-lib,
  lib,
  inputs,
  ...
}:
let
  devshell = hasInput inputs "devshell";

  infix-lib = import ../../lib {
    inherit
      lib
      ;
  };

  inherit (flake-parts-lib)
    mkPerSystemOption
    ;

  inherit (infix-lib)
    hasInput
    ;

  inherit (lib)
    attrValues
    escapeShellArg
    flatten
    map
    mapAttrs
    mkOption
    optionalString
    types
    ;

  filesModule =
    {
      config,
      pkgs,
      ...
    }:
    let
      inherit (pkgs)
        coreutils
        ;

      mkStartup =
        _: file:
        let
          source = escapeShellArg (toString file.file);
          target = escapeShellArg file.path;
        in
        {
          inherit (file)
            deps
            ;

          text = ''
            target="$PRJ_ROOT"/${target}
            targetDirectory="$(${coreutils}/bin/dirname "$target")"

            ${coreutils}/bin/mkdir -p "$targetDirectory"
            ${coreutils}/bin/ln -sfnT ${source} "$target"
          ''
          + optionalString (file.hook != "") ''

            ${file.hook}
          '';
        };

      module =
        {
          config,
          ...
        }:
        {
          options = {
            data = mkOption {
              description = ''
                Structured data passed to the file generator.
              '';

              type = types.anything;
            };

            deps = mkOption {
              default = [ ];

              description = ''
                Startup entries that must run before this file is linked.
              '';

              type = with types; listOf str;
            };

            file = mkOption {
              description = ''
                Generated store file for this file entry.
              '';

              internal = true;
              type = types.unspecified;
            };

            generator = mkOption {
              description = ''
                Function that turns `data` into a generated store file.
              '';

              type = types.functionTo types.unspecified;
            };

            hook = mkOption {
              default = "";

              description = ''
                Extra shell hook appended after linking this file.
              '';

              type = types.lines;
            };

            packages = mkOption {
              default = [ ];

              description = ''
                Packages needed by this generated file or its hook.
              '';

              type = with types; listOf package;
            };

            path = mkOption {
              description = ''
                Project-root-relative path for the linked generated file.
              '';

              type = types.strMatching "[^/].*";
            };
          };

          config = {
            file = config.generator config.data;
          };
        };
    in
    {
      options = {
        files = mkOption {
          default = { };

          description = ''
            Generated files linked into the project when entering the shell.
          '';

          type = with types; lazyAttrsOf (submodule module);
        };
      };

      config = {
        devshell = {
          packages =
            let
              liftPackages = attrs: attrs.packages;
            in
            flatten (
              map liftPackages (attrValues config.files)
            );

          startup = mapAttrs mkStartup config.files;
        };
      };
    };

in
{
  options = {
    perSystem = mkPerSystemOption (
      {
        config,
        pkgs,
        ...
      }:
      let
        module =
          import "${devshell}/modules/eval-args.nix"
            {
              inherit
                lib
                pkgs
                ;

              modules = [
                filesModule
              ];
            };
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
              lazyAttrsOf (submoduleWith module);
          };
        };

        config = {
          devShells =
            let
              liftShell = attrs: attrs.devshell.shell;
            in
            mapAttrs (_: liftShell) config.devshells;
        };
      }
    );
  };
}
