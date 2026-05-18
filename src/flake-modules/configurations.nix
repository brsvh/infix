{
  config,
  inputs,
  lib,
  ...
}:
let
  home-manager = hasInput inputs "home-manager";

  infix-lib = import ../../lib {
    inherit
      lib
      ;
  };

  nixpkgs = hasInput inputs "nixpkgs";

  inherit (infix-lib)
    hasInput
    ;

  inherit (lib)
    isAttrs
    mapAttrs
    mapAttrsToList
    mkDefault
    mkOption
    removeAttrs
    types
    ;

  configurations = config.configurations;

  homeModules = mkOption {
    default = [ ];

    description = ''
      Home Manager modules imported into generated home configurations.
    '';

    type = with types; listOf deferredModule;
  };

  profiles = mkOption {
    default = [ ];

    description = ''
      Profiles imported into the generated configuration.
    '';

    type = with types; listOf deferredModule;
  };

  specialArgs = mkOption {
    default = inputs;

    description = ''
      Extra module arguments passed to generated configurations.
    '';

    type = with types; lazyAttrsOf raw;
  };

  homeNixpkgs =
    {
      input,
      system,
    }:
    {
      ...
    }:
    {
      options = {
        config = mkOption {
          default = { };

          description = ''
            Nixpkgs configuration.
          '';

          type = with types; lazyAttrsOf raw;
        };

        input = mkOption {
          default = input;

          description = ''
            Nixpkgs input used to instantiate this home configuration.
          '';

          type = types.raw;
        };

        overlays = mkOption {
          default = [ ];

          description = ''
            Overlays applied when instantiating Nixpkgs.
          '';

          type = with types; listOf raw;
        };

        system = mkOption {
          default = system;

          description = ''
            Nixpkgs system used for this home configuration.
          '';

          type = types.str;
        };
      };
    };

  homeGlobalModule =
    {
      ...
    }:
    {
      options = {
        inherit
          specialArgs
          ;

        modules = homeModules;

        nixpkgs = mkOption {
          default = { };

          description = ''
            Default Nixpkgs input and settings for home configurations.
          '';

          type = types.submodule (homeNixpkgs {
            input = nixpkgs;
            system = "x86_64-linux";
          });
        };
      };
    };

  perHomeConfiguration =
    home:
    {
      ...
    }:
    {
      options = {
        inherit
          profiles
          specialArgs
          ;

        configurationType = mkOption {
          default = "home";
          internal = true;

          description = ''
            Internal marker for home configuration references.
          '';

          type = types.enum [
            "home"
          ];
        };

        home = mkOption {
          description = ''
            Main Home Manager module for this home configuration.
          '';

          type = types.deferredModule;
        };

        modules = homeModules;

        nixpkgs = mkOption {
          default = { };

          description = ''
            Nixpkgs input and settings for this home configuration.
          '';

          type = types.submodule (homeNixpkgs {
            input = home.global.nixpkgs.input;
            system = home.global.nixpkgs.system;
          });
        };
      };
    };

  homeModule =
    {
      config,
      ...
    }:
    {
      freeformType =
        with types;
        lazyAttrsOf (
          submodule (perHomeConfiguration config)
        );

      options = {
        global = mkOption {
          default = { };

          description = ''
            Default settings for home configurations.
          '';

          type = types.submodule homeGlobalModule;
        };
      };
    };

  mkHome =
    _: homeConfiguration:
    let
      extraSpecialArgs =
        configurations.home.global.specialArgs
        // homeConfiguration.specialArgs;

      modules =
        configurations.home.global.modules
        ++ homeConfiguration.modules
        ++ homeConfiguration.profiles
        ++ [
          homeConfiguration.home
        ];

      pkgs = import homeConfiguration.nixpkgs.input {
        inherit (homeConfiguration.nixpkgs)
          system
          ;

        config =
          configurations.home.global.nixpkgs.config
          // homeConfiguration.nixpkgs.config;

        overlays =
          configurations.home.global.nixpkgs.overlays
          ++ homeConfiguration.nixpkgs.overlays;
      };
    in
    home-manager.lib.homeManagerConfiguration {
      inherit
        extraSpecialArgs
        modules
        pkgs
        ;
    };

  homeConfigurations =
    removeAttrs configurations.home
      [
        "global"
      ];

  systemModules = mkOption {
    default = [ ];

    description = ''
      NixOS modules imported into generated system configurations.
    '';

    type = with types; listOf deferredModule;
  };

  systemNixpkgs =
    {
      input,
    }:
    {
      ...
    }:
    {
      options = {
        config = mkOption {
          default = { };

          description = ''
            Nixpkgs configuration.
          '';

          type = with types; lazyAttrsOf raw;
        };

        input = mkOption {
          default = input;

          description = ''
            Nixpkgs input used to instantiate this NixOS configuration.
          '';

          type = types.raw;
        };

        overlays = mkOption {
          default = [ ];

          description = ''
            Overlays applied when instantiating Nixpkgs.
          '';

          type = with types; listOf raw;
        };
      };
    };

  systemGlobalModule =
    {
      ...
    }:
    {
      options = {
        inherit
          specialArgs
          ;

        modules = systemModules;

        nixpkgs = mkOption {
          default = { };

          description = ''
            Default Nixpkgs input and settings for NixOS configurations.
          '';

          type = types.submodule (systemNixpkgs {
            input = nixpkgs;
          });
        };
      };
    };

  perSystemUserModule =
    {
      ...
    }:
    {
      options = {
        inherit
          profiles
          specialArgs
          ;

        home = mkOption {
          description = ''
            Home module, or a value from configurations.home.
          '';

          type = types.raw;
        };

        modules = homeModules;

        user = mkOption {
          description = ''
            NixOS module declaring this user.
          '';

          type = types.deferredModule;
        };
      };
    };

  perSystemConfiguration =
    system:
    {
      ...
    }:
    {
      options = {
        inherit
          profiles
          specialArgs
          ;

        modules = systemModules;

        nixpkgs = mkOption {
          default = { };

          description = ''
            Nixpkgs input and settings for this NixOS configuration.
          '';

          type = types.submodule (systemNixpkgs {
            input = system.global.nixpkgs.input;
          });
        };

        system = mkOption {
          description = ''
            Main NixOS module for this system configuration.
          '';

          type = types.deferredModule;
        };

        users = mkOption {
          default = { };

          description = ''
            Users declared by this NixOS configuration.
          '';

          type =
            with types;
            lazyAttrsOf (submodule perSystemUserModule);
        };
      };
    };

  systemModule =
    {
      config,
      ...
    }:
    {
      freeformType =
        with types;
        lazyAttrsOf (
          submodule (perSystemConfiguration config)
        );

      options = {
        global = mkOption {
          default = { };

          description = ''
            Default settings for NixOS configurations.
          '';

          type = types.submodule systemGlobalModule;
        };
      };
    };

  mkSystem =
    systemName: systemConfiguration:
    let
      mkUserModule =
        userName: userConfiguration:
        let
          isHomeConfiguration =
            candidate:
            isAttrs candidate
            && (
              let
                configurationType =
                  candidate.configurationType or null;
              in
              configurationType == "home"
            );

          modules =
            if
              (isHomeConfiguration userConfiguration.home)
            then
              configurations.home.global.modules
              ++ userConfiguration.home.modules
              ++ userConfiguration.home.profiles
              ++ [
                userConfiguration.home.home
              ]
            else
              userConfiguration.modules
              ++ userConfiguration.profiles
              ++ [
                userConfiguration.home
              ];
        in
        {
          imports = [
            userConfiguration.user
          ];

          home-manager = {
            users = {
              ${userName} =
                {
                  ...
                }:
                {
                  imports = modules;
                };
            };
          };
        };

      specialArgs =
        configurations.system.global.specialArgs
        // systemConfiguration.specialArgs;

      userModules = mapAttrsToList mkUserModule systemConfiguration.users;

      modules = [
        {
          networking = {
            hostName = mkDefault "${systemName}";
          };
        }
        home-manager.nixosModules.home-manager
        {
          home-manager = {
            extraSpecialArgs = specialArgs;

            useGlobalPkgs = true;
            useUserPackages = true;
          };
        }
        {
          nixpkgs = {
            config =
              configurations.system.global.nixpkgs.config
              // systemConfiguration.nixpkgs.config;

            overlays =
              configurations.system.global.nixpkgs.overlays
              ++ systemConfiguration.nixpkgs.overlays;
          };
        }
      ]
      ++ configurations.system.global.modules
      ++ systemConfiguration.modules
      ++ [
        systemConfiguration.system
      ]
      ++ systemConfiguration.profiles
      ++ userModules;
    in
    systemConfiguration.nixpkgs.input.lib.nixosSystem
      {
        inherit
          modules
          specialArgs
          ;
      };

  systemConfigurations =
    removeAttrs configurations.system
      [
        "global"
      ];

  configurationsModule =
    {
      ...
    }:
    {
      options = {
        finalHomeConfigurations = mkOption {
          default = { };
          internal = true;

          description = ''
            Final generated Home Manager configurations.
          '';

          type = with types; lazyAttrsOf raw;
        };

        finalNixOSConfigurations = mkOption {
          default = { };
          internal = true;

          description = ''
            Final generated NixOS configurations.
          '';

          type = with types; lazyAttrsOf raw;
        };

        home = mkOption {
          default = { };

          description = ''
            Home Manager configuration declarations.
          '';

          type = types.submodule homeModule;
        };

        system = mkOption {
          default = { };

          description = ''
            NixOS configuration declarations.
          '';

          type = types.submodule systemModule;
        };
      };
    };
in
{
  options = {
    configurations = mkOption {
      default = { };

      description = ''
        Declarative wrapper for flake homeConfigurations and
        nixosConfigurations.
      '';

      type = types.submodule configurationsModule;
    };
  };

  config = {
    configurations = {
      finalHomeConfigurations = mapAttrs mkHome homeConfigurations;

      finalNixOSConfigurations = mapAttrs mkSystem systemConfigurations;
    };

    flake = {
      homeConfigurations =
        configurations.finalHomeConfigurations;

      nixosConfigurations =
        configurations.finalNixOSConfigurations;
    };
  };
}
