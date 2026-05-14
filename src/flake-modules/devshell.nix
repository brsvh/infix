{
  flake-parts-lib,
  lib,
  inputs,
  ...
}:
let
  agent-skills = hasInput inputs "agent-skills";
  agent-skills-lib = agent-skills.lib.agent-skills;
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
    attrNames
    attrValues
    filterAttrs
    escapeShellArg
    flatten
    map
    mapAttrs
    mapAttrs'
    mkIf
    mkOption
    nameValuePair
    optionalAttrs
    optionalString
    replaceStrings
    types
    ;

  inherit (agent-skills-lib)
    allowlistFor
    discoverCatalog
    mkBundle
    mkShellHook
    selectSkills
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
          generatedFile = file.generator file.data;
          source = escapeShellArg (toString generatedFile);
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

  skillsModule =
    {
      config,
      pkgs,
      system,
      ...
    }:
    let
      sourcePathType =
        with types;
        nullOr (either path str);

      normalizeSource = source: {
        filter = {
          maxDepth = source.filter.maxDepth or null;
          nameRegex = source.filter.nameRegex or null;
        };

        idPrefix = source.idPrefix or null;
        input = source.input or null;
        path = source.path or null;
        subdir = source.subdir or ".";
      };

      sourceModule =
        {
          config,
          ...
        }:
        {
          options = {
            enable = mkOption {
              default = [ ];

              description = ''
                Skill IDs to enable from this source.
              '';

              type = with types; listOf str;
            };

            enableAll = mkOption {
              default = config.enable == [ ];

              description = ''
                Enable every discovered skill from this source.
              '';

              type = types.bool;
            };

            filter = {
              maxDepth = mkOption {
                default = null;

                description = ''
                  Maximum recursive discovery depth for this source.
                '';

                type = with types; nullOr ints.positive;
              };

              nameRegex = mkOption {
                default = null;

                description = ''
                  Regular expression used to restrict discovered skill paths.
                '';

                type = with types; nullOr str;
              };
            };

            idPrefix = mkOption {
              default = null;

              description = ''
                Optional prefix prepended to discovered skill IDs.
              '';

              type = with types; nullOr str;
            };

            input = mkOption {
              default = null;

              description = ''
                Flake input name providing this skill source.
              '';

              type = with types; nullOr str;
            };

            path = mkOption {
              default = null;

              description = ''
                Filesystem path providing this skill source.
              '';

              type = sourcePathType;
            };

            subdir = mkOption {
              default = ".";

              description = ''
                Subdirectory under `path` or `input` containing skills.
              '';

              type = types.str;
            };
          };
        };

      skillModule =
        {
          name,
          ...
        }:
        {
          options = {
            deps = mkOption {
              default = [ ];

              description = ''
                Other skill startup markers this skill depends on.
              '';

              type = with types; listOf str;
            };

            enable = mkOption {
              default = true;

              description = ''
                Include this explicit skill in the generated bundle.
              '';

              type = types.bool;
            };

            from = mkOption {
              default = null;

              description = ''
                Source name providing this skill.
              '';

              type = with types; nullOr str;
            };

            meta = mkOption {
              default = { };

              description = ''
                Metadata attached to the explicit skill.
              '';

              type = with types; attrsOf anything;
            };

            packages = mkOption {
              default = [ ];

              description = ''
                Packages symlinked into the generated skill directory.
              '';

              type = with types; listOf package;
            };

            path = mkOption {
              default = name;

              description = ''
                Relative path under the selected source.
              '';

              type = types.str;
            };

            rename = mkOption {
              default = null;

              description = ''
                Optional skill ID used in the generated bundle.
              '';

              type = with types; nullOr str;
            };

            transform = mkOption {
              default = null;

              description = ''
                Function that transforms SKILL.md content.
              '';

              type = with types; nullOr raw;
            };
          };
        };

      targetModule =
        {
          ...
        }:
        {
          options = {
            dest = mkOption {
              description = ''
                Project-root-relative destination for installed skills.
              '';

              type = types.str;
            };

            enable = mkOption {
              default = true;

              description = ''
                Install skills into this target.
              '';

              type = types.bool;
            };

            structure = mkOption {
              default = "symlink-tree";

              description = ''
                Install target structure used by agent-skills-nix.
              '';

              type =
                with types;
                enum [
                  "copy-tree"
                  "link"
                  "symlink-tree"
                ];
            };
          };
        };

      cfg = config.skills;

      hasSkillConfig =
        cfg.sources != { } || cfg.skills != { };

      cleanSources = mapAttrs (
        _: normalizeSource
      ) cfg.sources;

      mkExplicitSkill =
        _: skill:
        {
          inherit (skill)
            enable
            packages
            path
            ;
        }
        // optionalAttrs (skill.from != null) {
          inherit (skill)
            from
            ;
        }
        // optionalAttrs (skill.meta != { }) {
          inherit (skill)
            meta
            ;
        }
        // optionalAttrs (skill.rename != null) {
          inherit (skill)
            rename
            ;
        }
        // optionalAttrs (skill.transform != null) {
          inherit (skill)
            transform
            ;
        };

      enabledExplicitSkills = filterAttrs (
        _: skill: skill.enable
      ) cfg.skills;

      explicitSkills = mapAttrs mkExplicitSkill cfg.skills;

      explicitSkillIds = mapAttrs (
        name: skill:
        if skill.rename != null then
          skill.rename
        else
          name
      ) cfg.skills;

      catalog = discoverCatalog cleanSources;

      enabledSourceNames = attrNames (
        filterAttrs (
          _: source: source.enableAll
        ) cfg.sources
      );

      enabledSkillIds = flatten (
        map (source: source.enable) (
          attrValues cfg.sources
        )
      );

      allowlist = allowlistFor {
        inherit
          catalog
          ;

        enable = enabledSkillIds;
        enableAll = enabledSourceNames;
        sources = cleanSources;
      };

      selection = selectSkills {
        inherit
          catalog
          allowlist
          ;

        skills = explicitSkills;
        sources = cleanSources;
      };

      skillStartupName =
        id: "skill-${replaceStrings [ "/" ] [ "-" ] id}";

      explicitDeps = mapAttrs' (
        name: skill:
        nameValuePair explicitSkillIds.${name} (
          map (
            dep:
            skillStartupName (explicitSkillIds.${dep} or dep)
          ) skill.deps
        )
      ) enabledExplicitSkills;

      bundle = mkBundle {
        inherit
          pkgs
          selection
          ;
      };

      targets = mapAttrs (
        _: target:
        target
        // {
          systems = [
            system
          ];
        }
      ) cfg.targets;

      shellHook = mkShellHook {
        inherit
          bundle
          pkgs
          targets
          ;

        excludePatterns = cfg.excludePatterns;
      };

      skillStartup = mapAttrs' (
        id: _:
        nameValuePair (skillStartupName id) {
          deps = explicitDeps.${id} or [ ];
          text = ":";
        }
      ) selection;
    in
    {
      options = {
        skills = mkOption {
          default = { };

          description = ''
            Agent skills installed when entering this devshell.
          '';

          type = types.submodule {
            options = {
              excludePatterns = mkOption {
                default = [
                  "/.system"
                ];

                description = ''
                  Patterns excluded while synchronising skill targets.
                '';

                type = with types; listOf str;
              };

              skills = mkOption {
                default = { };

                description = ''
                  Explicit skills selected for this devshell.
                '';

                type =
                  with types;
                  lazyAttrsOf (submodule skillModule);
              };

              sources = mkOption {
                default = { };

                description = ''
                  Skill source repositories used by this devshell.
                '';

                type =
                  with types;
                  lazyAttrsOf (submodule sourceModule);
              };

              targets = mkOption {
                default = { };

                description = ''
                  Project-local skill installation targets.
                '';

                type =
                  with types;
                  lazyAttrsOf (submodule targetModule);
              };
            };
          };
        };
      };

      config =
        mkIf (hasSkillConfig && selection != { })
          {
            devshell = {
              startup = skillStartup // {
                agent-skills = {
                  deps = attrNames skillStartup;

                  text = shellHook;
                };
              };
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
        system,
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
                skillsModule
              ];

              extraSpecialArgs = {
                inherit
                  system
                  ;
              };
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
