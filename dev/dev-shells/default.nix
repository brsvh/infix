{
  lib,
  pkgs,
  ...
}:
let
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

  files = {
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

      engine =
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

      engine =
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
