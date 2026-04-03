{
  config,
  flake-parts-lib,
  lib,
  inputs,
  ...
}:
let
  inherit (builtins)
    toString
    ;

  infix-lib = import ../../lib {
    inherit
      lib
      ;
  };

  inherit (infix-lib)
    dirToAttrs
    mapAttrsRecursive'
    mapAttrsRecursiveCond'
    stemOf
    ;

  inherit (lib)
    filterAttrsRecursive
    hasAttr
    hasSuffix
    isAttrs
    last
    mapAttrs
    mapAttrsToList
    mapAttrsToListRecursive
    mkDefault
    mkOption
    nameValuePair
    optionals
    pathExists
    pipe
    types
    ;

  requireInput =
    input:
    if hasAttr input inputs then
      inputs.${input}
    else
      throw ''
        ${input} input not found, please add a ${input} input to your flake.
      '';

  optionalInput =
    input:
    if hasAttr input inputs then
      inputs.${input}
    else
      null;

  nixpkgs = requireInput "nixpkgs";

  disko = optionalInput "disko";

  facter = optionalInput "facter";

  home-manager = optionalInput "home-manager";

  userModule =
    {
      config,
      ...
    }:
    {
      options = {
        directory = mkOption {
          description = ''
            The Home Configuration directory.
          '';

          type = types.path;
        };

        etcDirectory = mkOption {
          defaultText = "${config.directory}/etc";

          description = ''
            The directory beneath which user-wide configuration files.
          '';

          type = types.path;
        };

        homeFile = mkOption {
          defaultText = "${config.directory}/home.nix";

          description = ''
            The top-level Home Configuration File.
          '';

          type = types.path;
        };

        modules = mkOption {
          default = [ ];

          description = ''
            Extra Home modules applied to the Home Configuration.

            Accepts module paths,  or inline module functions.
          '';

          type = with types; listOf deferredModule;
        };

        modulesDirectory = mkOption {
          defaultText = "${config.directory}/modules";

          description = ''
            The directory beneath which user-wide Home modules.
          '';

          type = types.path;
        };

        profiles = mkOption {
          default = [ ];

          description = ''
            Extra Home profiles applied to the Home Configuration.

            Inhere profiles are config-only module, accepts module paths, or
            inline module functions.
          '';

          type = with types; listOf deferredModule;
        };

        profilesDirectory = mkOption {
          defaultText = "${config.directory}/profiles";

          description = ''
            The directory beneath which user-wide Home profiles.
          '';

          type = types.path;
        };

        userFile = mkOption {
          defaultText = "${config.directory}/user.nix";

          description = ''
            The user declaration file for NixOS Configuration.
          '';

          type = types.path;
        };
      };

      config = {
        etcDirectory = mkDefault (
          config.directory + /etc
        );

        homeFile = mkDefault (
          config.directory + /home.nix
        );

        modulesDirectory = mkDefault (
          config.directory + /modules
        );

        profilesDirectory = mkDefault (
          config.directory + /profiles
        );

        userFile = mkDefault (
          config.directory + /user.nix
        );
      };
    };

  nixosConfigurationModule =
    {
      config,
      ...
    }:
    {
      options = {
        directory = mkOption {
          description = ''
            The NixOS Configuration directory.
          '';

          type = types.path;
        };

        diskoFile = mkOption {
          defaultText = "${config.directory}/disko.nix";

          description = ''
            The file-systems declaration file (by Disko).
          '';

          type = types.path;
        };

        enableDisko = mkOption {
          default = disko != null;

          description = ''
            Whether to import disko.nixosModules.disko and diskoFile.
          '';

          type = types.bool;
        };

        enableFacter = mkOption {
          default = facter != null;

          description = ''
            Whether to import facter.nixosModules.facter and facterReportFile.
          '';

          type = types.bool;
        };

        enableHomeManager = mkOption {
          default = home-manager != null;

          description = ''
            Whether to import home-manager.nixosModules.home-manager.
          '';

          type = types.bool;
        };

        etcDirectory = mkOption {
          defaultText = "${config.directory}/etc";

          description = ''
            The directory beneath which system-wide configuration files.
          '';

          type = types.path;
        };

        facterReportFile = mkOption {
          defaultText = "${config.directory}/etc/facter.json";

          description = ''
            Path to a report generated by nixos-facter.
          '';

          type = types.path;
        };

        modules = mkOption {
          default = [ ];

          description = ''
            Extra NixOS modules applied to the NixOS Configuration.

            Accepts module paths,  or inline module functions.
          '';

          type = with types; listOf deferredModule;
        };

        modulesDirectory = mkOption {
          defaultText = "${config.directory}/modules";

          description = ''
            The directory beneath which system-wide NixOS modules.
          '';

          type = types.path;
        };

        profiles = mkOption {
          default = [ ];

          description = ''
            Extra NixOS profiles applied to the NixOS Configuration.

            Inhere profiles are config-only module, accepts module paths, or
            inline module functions.
          '';

          type = with types; listOf deferredModule;
        };

        profilesDirectory = mkOption {
          defaultText = "${config.directory}/profiles";

          description = ''
            The directory beneath which system-wide NixOS profiles.
          '';

          type = types.path;
        };

        specialArgs = mkOption {
          default = { };

          description = ''
            Special arguments to pass to NixOS Configuration.
          '';

          type = types.attrsOf types.anything;
        };

        systemFile = mkOption {
          defaultText = "${config.directory}/system.nix";

          description = ''
            The top-level NixOS Configuration File.
          '';

          type = types.path;
        };

        users = mkOption {
          default = { };

          description = ''
            The User Configurations.
          '';

          type =
            with types;
            lazyAttrsOf (submoduleWith {
              modules = [
                userModule
              ];
            });
        };
      };

      config = {
        diskoFile = mkDefault (
          config.directory + /disko.nix
        );

        etcDirectory = mkDefault (
          config.directory + /etc
        );

        facterReportFile = mkDefault (
          config.directory + /etc/facter.json
        );

        modulesDirectory = mkDefault (
          config.directory + /modules
        );

        profilesDirectory = mkDefault (
          config.directory + /profiles
        );

        systemFile = mkDefault (
          config.directory + /system.nix
        );
      };
    };

  mkNixOSConfiguration =
    name:
    value@{
      directory,
      diskoFile,
      enableDisko,
      enableFacter,
      enableHomeManager,
      etcDirectory,
      facterReportFile,
      modules,
      modulesDirectory,
      profiles,
      profilesDirectory,
      specialArgs,
      systemFile,
      users,
      ...
    }:
    let
      liftDefaultAttrs =
        mapAttrsRecursiveCond'
          (v: !(isAttrs v && v ? default))
          (
            path: v:
            nameValuePair (stemOf (last path)) (
              if isAttrs v && v ? default then v.default else v
            )
          );

      removePathAttrs = filterAttrsRecursive (
        name: _: name != "__path"
      );

      keepOnlyNixAttrs = filterAttrsRecursive (
        name: value:
        if (isAttrs value) || (name == "__path") then
          true
        else
          hasSuffix ".nix" (toString value)
      );

      moduleDirToAttrs =
        dir:
        if pathExists dir then
          pipe (dirToAttrs dir) [
            keepOnlyNixAttrs
            liftDefaultAttrs
            removePathAttrs
          ]
        else
          { };

      etcDirToAttrs =
        dir:
        if pathExists dir then
          pipe (dirToAttrs dir) [
            (mapAttrsRecursive' (
              path: value:
              if (last path) == "__path" then
                nameValuePair "__path" value
              else
                nameValuePair (stemOf (last path)) value
            ))
          ]
        else
          { };

      dirToList =
        dir:
        mapAttrsToListRecursive (_: v: v) (
          moduleDirToAttrs dir
        );

      userModuleList =
        (mapAttrsToList (_: v: v.userFile) users)
        ++ (mapAttrsToList (n: v: {
          home-manager = {
            users = {
              ${n} =
                { ... }:
                {
                  imports =
                    v.modules
                    ++ (dirToList v.modulesDirectory)
                    ++ [ v.homeFile ]
                    ++ v.profiles
                    ++ (dirToList v.profilesDirectory);
                };
            };
          };
        }) users);

      usersSpecialArgs = mapAttrs (_: v: {
        etc = etcDirToAttrs v.etcDirectory;
        modules = moduleDirToAttrs v.modulesDirectory;
        profiles = moduleDirToAttrs v.profilesDirectory;
      }) users;

      finalSpecialArgs = {
        inherit
          inputs
          ;
      }
      // specialArgs
      // {
        ${name} = {
          etc = etcDirToAttrs etcDirectory;
          modules = moduleDirToAttrs modulesDirectory;
          profiles = moduleDirToAttrs profilesDirectory;
        };
      }
      // usersSpecialArgs;

      finalModules = [
        {
          assertions = [
            {
              assertion = !enableDisko || disko != null;
              message = ''
                nixosConfigurations.${name}.enableDisko = true requires the
                disko flake input.
              '';
            }
            {
              assertion = !enableFacter || facter != null;
              message = ''
                nixosConfigurations.${name}.enableFacter = true requires the
                facter flake input.
              '';
            }
            {
              assertion =
                !enableHomeManager || home-manager != null;
              message = ''
                nixosConfigurations.${name}.enableHomeManager = true requires
                the home-manager flake input.
              '';
            }
          ];
        }
        {
          networking = {
            hostName = mkDefault "${name}";
          };
        }
      ]
      ++ (optionals enableDisko [
        disko.nixosModules.disko
        diskoFile
      ])
      ++ (optionals enableFacter [
        facter.nixosModules.facter
        {
          facter.reportPath = facterReportFile;
        }
      ])
      ++ modules
      ++ (dirToList modulesDirectory)
      ++ [
        systemFile
      ]
      ++ profiles
      ++ (dirToList profilesDirectory)
      ++ [
        home-manager.nixosModules.home-manager
        {
          home-manager = {
            extraSpecialArgs = finalSpecialArgs;
          };
        }
      ]
      ++ userModuleList;
    in
    nixpkgs.lib.nixosSystem {
      modules = finalModules;
      specialArgs = finalSpecialArgs;
    };
in
{
  options = {
    nixosConfigurations = mkOption {
      default = { };

      description = ''
        The NixOS Configurations.
      '';

      type =
        with types;
        lazyAttrsOf (submoduleWith {
          modules = [
            nixosConfigurationModule
          ];
        });
    };
  };

  config = {
    flake = {
      nixosConfigurations = mapAttrs mkNixOSConfiguration config.nixosConfigurations;
    };
  };
}
