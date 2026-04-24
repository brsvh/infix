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
    filter
    filterAttrs
    flatten
    hasPrefix
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

  skillSubmodule =
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

  mcpServerSubmodule =
    {
      ...
    }:
    {
      options = {
        package = mkOption {
          default = null;

          description = ''
            MCP server package installed alongside the Codex CLI in the target
            devshell. When unset, no package is added automatically.
          '';

          type = with types; nullOr package;
        };

        settings = mkOption {
          default = { };

          description = ''
            MCP server settings merged into `settings.mcp_servers.<name>`.
          '';

          type = with types; attrsOf anything;
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

        package = mkOption {
          default = null;

          description = ''
            Codex CLI package installed in the target devshell. When unset,
            `pkgs.codex` is used.
          '';

          type = with types; nullOr package;
        };

        devshellName = mkOption {
          default = "default";

          description = ''
            The devshell receiving generated Codex files, startup hooks, MCP
            server packages, and skill runtime dependencies.
          '';

          type = types.str;
        };

        mcp = mkOption {
          default = { };

          description = ''
            MCP server definitions merged into `settings.mcp_servers` and
            installed alongside the Codex CLI in the target devshell when a
            package is configured.
          '';

          type =
            with types;
            lazyAttrsOf (submoduleWith {
              modules = [
                mcpServerSubmodule
              ];
            });
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

        docs = {
          directory = mkOption {
            default = null;

            description = ''
              Source directory linked into `.agents/docs`.
            '';

            type = types.nullOr types.path;
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
              fallbackDocPaths =
                let
                  configuredPaths =
                    data.project_doc_fallback_filenames or [ ];
                in
                unique (
                  (
                    if configuredPaths == null then
                      [ ]
                    else
                      configuredPaths
                  )
                  ++ [
                    config.readme.path
                  ]
                );

              settingsMcpServers = data.mcp_servers or { };

              declaredMcpServers = mapAttrs (
                _: serverConfig: serverConfig.settings
              ) config.mcp;
            in
            data
            // {
              mcp_servers =
                settingsMcpServers // declaredMcpServers;
              project_doc_fallback_filenames = fallbackDocPaths;
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
                skillSubmodule
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
        codex = config.codex;
        docsLinkPath = ".agents/docs";

        cliPackage =
          if codex.package == null then
            pkgs.codex
          else
            codex.package;

        fallbackDocPaths =
          codex.settings.project_doc_fallback_filenames;

        configFileData =
          let
            data = pruneNulls codex.settings;
          in
          if data == null then { } else data;

        fallbackDocDirectories =
          let
            candidateDirectories = unique (
              map dirOf fallbackDocPaths
            );
          in
          if codex.docs.directory == null then
            candidateDirectories
          else
            filter (
              directory:
              !(
                directory == docsLinkPath
                || hasPrefix "${docsLinkPath}/" directory
              )
            ) candidateDirectories;

        skillRuntimePackages = flatten (
          map (skill: skill.packages) (
            attrValues codex.skills
          )
        );

        mcpPackages = filter (package: package != null) (
          map (server: server.package) (
            attrValues codex.mcp
          )
        );

        skillNames = attrNames codex.skills;

        skillLinksScript = concatStringsSep "\n" (
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
              skillConfig = codex.skills.${name};
            in
            "ln -snf ${escapeShellArg (toString skillConfig.directory)} ${escapeShellArg ".agents/skills/${name}"}"
          ) skillNames
        );

        docsLinkScript =
          if codex.docs.directory == null then
            ''
              if [ -L ${escapeShellArg docsLinkPath} ]; then
                rm -f ${escapeShellArg docsLinkPath}
              fi
            ''
          else
            ''
              mkdir -p ${escapeShellArg (dirOf docsLinkPath)}
              ln -snf ${escapeShellArg (toString codex.docs.directory)} ${escapeShellArg docsLinkPath}
            '';

        devshellName = codex.devshellName;
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

        config = mkIf codex.enable {
          devshells = {
            ${devshellName} = {
              ago = {
                codex = {
                  data = configFileData;
                  format = "toml";
                  output = ".codex/config.toml";

                  packages = [
                    cliPackage
                  ]
                  ++ mcpPackages;
                };
              };

              devshell = mkMerge [
                {
                  packages = skillRuntimePackages;
                }

                (mkIf (fallbackDocDirectories != [ ]) {
                  startup = {
                    "codex-doc-directories" = {
                      text = concatStringsSep "\n" (
                        map (
                          directory: "mkdir -p ${escapeShellArg directory}"
                        ) fallbackDocDirectories
                      );
                    };
                  };
                })

                {
                  startup = {
                    "codex-doc-link" = {
                      text = docsLinkScript;
                    };

                    "codex-readme-link" = {
                      text =
                        if codex.readme.file == null then
                          ''
                            if [ -L ${escapeShellArg codex.readme.path} ]; then
                              rm -f ${escapeShellArg codex.readme.path}
                            fi
                          ''
                        else
                          ''
                            mkdir -p ${escapeShellArg (dirOf codex.readme.path)}
                            ln -snf ${escapeShellArg (toString codex.readme.file)} ${escapeShellArg codex.readme.path}
                          '';
                    };

                    "codex-skill-links" = {
                      text = skillLinksScript;
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
