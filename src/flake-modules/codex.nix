{
  flake-parts-lib,
  lib,
  ...
}:
let
  inherit (flake-parts-lib)
    mkPerSystemOption
    ;

  inherit (lib)
    attrNames
    attrValues
    concatStringsSep
    dirOf
    escapeShellArg
    filterAttrs
    flatten
    isAttrs
    map
    mapAttrs
    mkIf
    mkMerge
    mkOption
    types
    unique
    ;

  pruneNulls =
    value:
    if isAttrs value then
      let
        filtered = filterAttrs (_: v: v != null) (
          mapAttrs (_: pruneNulls) value
        );
      in
      if filtered == { } then null else filtered
    else
      value;

  codexSkillOptions =
    {
      ...
    }:
    {
      options = {
        directory = mkOption {
          description = ''
            Skill directory linked into `.agents/skills/<name>`.
          '';

          type = types.path;
        };

        packages = mkOption {
          default = [ ];

          description = ''
            Runtime dependencies of the skill, added to the target devshell.
          '';

          type = with types; listOf package;
        };
      };
    };

  codexOptions =
    {
      config,
      ...
    }:
    {
      options = {
        enable = mkOption {
          default = false;

          description = ''
            Whether to enable Codex integration for the current system.
          '';

          type = types.bool;
        };

        stateVersion = mkOption {
          default = "0.118.0";

          description = ''
            Describes the Codex version targeted by the current module.

            This is informational for now, and reserved for future
            compatibility guards.
          '';

          type = types.str;
        };

        devshellName = mkOption {
          default = "default";

          description = ''
            The devshell receiving generated Codex files, startup hooks, and
            skill runtime dependencies.
          '';

          type = types.str;
        };

        MCPServers = mkOption {
          default = [ ];

          description = ''
            MCP server packages installed alongside the Codex CLI in the target
            devshell.
          '';

          type = with types; listOf package;
        };

        readme = {
          file = mkOption {
            default = null;

            description = ''
              Source file linked into the project as repository instructions for
              Codex.
            '';

            type = types.nullOr types.path;
          };

          path = mkOption {
            default = ".agents/AGENTS.md";

            description = ''
              Relative project path where `readme.file` will be linked.
            '';

            type = types.str;
          };
        };

        settings = mkOption {
          default = { };

          description = ''
            Data written to `.codex/config.toml`.
          '';

          apply =
            data:
            let
              projectDocFallbackFilenames =
                let
                  configured =
                    data.project_doc_fallback_filenames or [ ];
                in
                unique (
                  (if configured == null then [ ] else configured)
                  ++ [
                    config.readme.path
                  ]
                );
            in
            data
            // {
              project_doc_fallback_filenames =
                projectDocFallbackFilenames;
            };

          type = with types; attrsOf anything;
        };

        skills = mkOption {
          default = { };

          description = ''
            Skill directories linked into `.agents/skills`.
          '';

          type =
            with types;
            lazyAttrsOf (submoduleWith {
              modules = [
                codexSkillOptions
              ];
            });
        };
      };
    };
in
{
  imports = [
    ./devshell.nix
  ];

  options = {
    perSystem = mkPerSystemOption (
      {
        config,
        pkgs,
        ...
      }:
      let
        codexConfig = config.codex;

        projectDocFallbackFilenames =
          codexConfig.settings.project_doc_fallback_filenames;

        settingsData =
          let
            data = pruneNulls codexConfig.settings;
          in
          if data == null then { } else data;

        projectDocDirectories = unique (
          map dirOf projectDocFallbackFilenames
        );

        skillPackages = flatten (
          map (skill: skill.packages) (
            attrValues codexConfig.skills
          )
        );

        skillNames = attrNames codexConfig.skills;

        skillStartupText = concatStringsSep "\n" (
          (
            if skillNames != [ ] then
              [ "mkdir -p ${escapeShellArg ".agents/skills"}" ]
            else
              [ ]
          )
          ++ [
            "if [ -d ${escapeShellArg ".agents/skills"} ]; then"
            "  for entry in ${escapeShellArg ".agents/skills"}/*; do"
            "    [ -e \"$entry\" ] || [ -L \"$entry\" ] || continue"
            "    [ -L \"$entry\" ] || continue"
            "    name=\"$(basename \"$entry\")\""
          ]
          ++ (
            if skillNames == [ ] then
              [ "    rm -f \"$entry\"" ]
            else
              [
                "    case \"$name\" in"
                "      ${concatStringsSep "|" (map escapeShellArg skillNames)}) ;;"
                "      *) rm -f \"$entry\" ;;"
                "    esac"
              ]
          )
          ++ [
            "  done"
            "fi"
          ]
          ++ map (
            name:
            let
              skill = codexConfig.skills.${name};
            in
            "ln -snf ${escapeShellArg (toString skill.directory)} ${escapeShellArg ".agents/skills/${name}"}"
          ) skillNames
        );

        targetDevshell = codexConfig.devshellName;
      in
      {
        options = {
          codex = mkOption {
            default = { };

            description = ''
              Configure project-wide Codex files, packages, and skill links with
              flake-parts.
            '';

            type =
              with types;
              submoduleWith {
                modules = [
                  codexOptions
                ];
              };
          };
        };

        config = mkIf codexConfig.enable {
          devshells = {
            ${targetDevshell} = {
              ago = {
                codex = {
                  data = settingsData;
                  format = "toml";
                  output = ".codex/config.toml";

                  packages = [
                    pkgs.codex
                  ]
                  ++ codexConfig.MCPServers;
                };
              };

              devshell = mkMerge [
                {
                  packages = skillPackages;
                }

                (mkIf (projectDocDirectories != [ ]) {
                  startup = {
                    "codex-project-doc" = {
                      text = concatStringsSep "\n" (
                        map (
                          directory: "mkdir -p ${escapeShellArg directory}"
                        ) projectDocDirectories
                      );
                    };
                  };
                })

                {
                  startup = {
                    "codex-readme" = {
                      text =
                        if codexConfig.readme.file == null then
                          ''
                            if [ -L ${escapeShellArg codexConfig.readme.path} ]; then
                              rm -f ${escapeShellArg codexConfig.readme.path}
                            fi
                          ''
                        else
                          ''
                            mkdir -p ${escapeShellArg (dirOf codexConfig.readme.path)}
                            ln -snf ${escapeShellArg (toString codexConfig.readme.file)} ${escapeShellArg codexConfig.readme.path}
                          '';
                    };

                    "codex-skills" = {
                      text = skillStartupText;
                    };
                  };
                }
              ];
            };
          };
        };
      }
    );
  };
}
