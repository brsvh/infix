{
  inputs,
  lib,
  pkgs,
  projectRoot,
  ...
}:
let
  inherit (inputs)
    bingshan-skills
    openai-skills
    ;

  inherit (inputs.agent-skills.lib.agent-skills)
    allowlistFor
    defaultLocalTargets
    discoverCatalog
    mkBundle
    mkShellHook
    selectSkills
    ;

  inherit (lib)
    attrNames
    baseNameOf
    concatMap
    concatMapStringsSep
    concatStringsSep
    elem
    escapeShellArg
    foldl'
    getExe
    map
    mapAttrs
    optional
    pipe
    removeAttrs
    ;

  inherit (lib.generators)
    toINIWithGlobalSection
    ;

  inherit (pkgs)
    git
    mkShell
    writeText
    ;

  skillSources = {
    bingshan = {
      idPrefix = "bingshan";
      path = "${bingshan-skills}";
      subdir = "skills";
    };

    infix = {
      idPrefix = "infix";
      path = projectRoot;
      subdir = "dev/agents/skills";
    };

    openai = {
      idPrefix = "openai";
      path = "${openai-skills}";
      subdir = "skills/.curated";
    };
  };

  skillCatalog = discoverCatalog skillSources;

  skillAllowlist = allowlistFor {
    catalog = skillCatalog;

    enable = [
      "bingshan/nix-gnu-style-commit"
      "bingshan/nix-code-refactor"
      "infix/commit"
      "openai/cli-creator"
    ];

    sources = skillSources;
  };

  skillSelection = selectSkills {
    allowlist = skillAllowlist;
    catalog = skillCatalog;
    sources = skillSources;

    skills = { };
  };

  skillBundle = mkBundle {
    inherit
      pkgs
      ;

    selection = skillSelection;
  };

  skillLocalTargets = {
    codex = defaultLocalTargets.codex // {
      enable = true;
    };
  };

  skillShellHook = mkShellHook {
    inherit
      pkgs
      ;

    bundle = skillBundle;
    targets = skillLocalTargets;
  };

  mkFile = request: request.engine request;

  install =
    request:
    let
      source = escapeShellArg (
        toString (mkFile request)
      );

      output = escapeShellArg request.output;
    in
    ''
      target="$projectRoot"/${output}
      mkdir -p "$(dirname -- "$target")"
      ln -sfn ${source} "$target"
    '';

  hookExtra =
    request:
    if request ? hook && request.hook ? extra then
      request.hook.extra request.data
    else
      "";

  installWithHook =
    request:
    let
      extra = hookExtra request;
    in
    concatStringsSep "\n" (
      [
        (install request)
      ]
      ++ optional (extra != "") extra
    );

  addFile =
    names: name:
    if elem name names then
      names
    else
      (foldl' addFile names (
        files.${name}.depends or [ ]
      ))
      ++ [
        name
      ];

  toml =
    request:
    let
      inherit (request)
        data
        output
        ;
    in
    (pkgs.formats.toml { }).generate
      (baseNameOf output)
      data;

  yaml =
    request:
    let
      inherit (request)
        data
        output
        ;
    in
    (pkgs.formats.yaml { }).generate
      (baseNameOf output)
      data;

  files = {
    codex = {
      data = {
        approval_policy = "on-request";
        model = "gpt-5.5";
        model_provider = "openai";
        model_reasoning_effort = "xhigh";
        model_reasoning_summary = "auto";
        model_verbosity = "high";
        personality = "pragmatic";
        plan_mode_reasoning_effort = "xhigh";

        project_doc_fallback_filenames = [
          "dev/agents/AGENTS.md"
        ];

        project_doc_max_bytes = 32768;
        review_model = "gpt-5.5";
        sandbox_mode = "workspace-write";
        service_tier = "fast";
        web_search = "cached";

        agents = {
          job_max_runtime_seconds = 1800;
          max_depth = 1;
          max_threads = 2;
        };

        sandbox_workspace_write = {
          exclude_slash_tmp = false;
          exclude_tmpdir_env_var = false;
          network_access = false;
          writable_roots = [ ];
        };

        shell_environment_policy = {
          "inherit" = "all";

          exclude = [ ];

          experimental_use_profile = false;
          ignore_default_excludes = false;

          include_only = [ ];

          set = { };
        };
      };

      engine = toml;
      output = ".codex/config.toml";

      packages = with pkgs; [
        codex
      ];
    };

    editorconfig = {
      data = {
        root = true;

        "*" = {
          charset = "utf-8";
          end_of_line = "lf";
          indent_size = 8;
          indent_style = "tab";
          insert_final_newline = true;
          max_line_length = 70;
          tab_width = 8;
        };

        "*.el" = {
          indent_style = "space";
          indent_size = "unset";
          tab_width = 2;
        };

        "*.md" = {
          indent_size = 2;
          indent_style = "space";
          max_line_length = 80;
          trim_trailing_whitespace = false;
        };

        "*.org" = {
          indent_size = 2;
          indent_style = "space";
          max_line_length = 80;
          trim_trailing_whitespace = false;
        };

        "*.nix" = {
          indent_style = "space";
          max_line_length = 80;
          tab_width = 2;
        };
      };

      engine =
        request:
        let
          inherit (request)
            data
            output
            ;

          name = baseNameOf output;

          value = {
            globalSection = {
              root = data.root or true;
            };

            sections = removeAttrs data [
              "root"
            ];
          };
        in
        writeText name (toINIWithGlobalSection { } value);

      output = ".editorconfig";

      packages = with pkgs; [
        editorconfig-checker
      ];
    };

    lefthook = {
      data = {
        pre-commit = {
          commands = {
            treefmt = {
              run = "treefmt --fail-on-change {staged_files}";

              skip = [
                "merge"
                "rebase"
              ];
            };
          };

          skip = [
            {
              ref = "update_flake_lock_action";
            }
          ];
        };
      };

      depends = [
        "treefmt"
      ];

      engine = yaml;

      hook = {
        extra =
          cfg:
          let
            inherit (pkgs)
              lefthook
              runtimeShell
              writeScript
              ;

            mkScript =
              stage:
              writeScript "lefthook-${stage}" ''
                #!${runtimeShell}
                [ "$LEFTHOOK" == "0" ] || \
                  ${getExe lefthook} run "${stage}" "$@"
              '';
          in
          pipe cfg [
            (
              config:
              removeAttrs config [
                "colors"
                "extends"
                "skip_output"
                "source_dir"
                "source_dir_local"
              ]
            )
            attrNames
            (map (
              stage:
              ''ln -sf "${mkScript stage}" "$projectRoot/.git/hooks/${stage}"''
            ))
            (
              stages:
              optional (stages != [ ]) ''
                mkdir -p "$projectRoot/.git/hooks"
              ''
              ++ stages
            )
            (concatStringsSep "\n")
          ];
      };

      output = "lefthook.yml";

      packages = with pkgs; [
        lefthook
      ];
    };

    treefmt = {
      data = {
        formatter = {
          emacs-lisp = {
            command = "elisp-format";

            includes = [
              "*.el"
            ];
          };

          markdown = {
            command = "mdformat";

            includes = [
              "*.md"
            ];

            options = [
              "--extensions=frontmatter"
              "--wrap=80"
            ];
          };

          nix = {
            command = "nixfmt";

            includes = [
              "*.nix"
            ];

            options = [
              "--width=50"
            ];
          };
        };
      };

      engine = toml;
      output = "treefmt.toml";

      packages =
        let
          mdformatWithPlugins = pkgs.mdformat.withPlugins (
            ps: with ps; [
              mdformat-frontmatter
            ]
          );
        in
        with pkgs;
        [
          elisp-format
          mdformatWithPlugins
          nixfmt
          treefmt
        ];
    };
  };

  names = foldl' addFile [ ] (attrNames files);
in
mkShell {
  packages =
    (concatMap (
      name: files.${name}.packages or [ ]
    ) names)
    ++ (with pkgs; [
      git
    ]);

  shellHook = concatStringsSep "\n" (
    [
      ''projectRoot="$(${getExe git} rev-parse --show-toplevel)"''
      ''export AGENT_SKILLS_ROOT="$projectRoot"''
      skillShellHook
    ]
    ++ map (name: installWithHook files.${name}) names
  );

  passthru = {
    dependencies = mapAttrs (_: request: {
      packages = request.packages or [ ];
    }) files;

    files = mapAttrs (_: mkFile) files;
  };
}
