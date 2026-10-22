{
  cacert,
  cargo,
  cmake,
  curl,
  fetchFromGitHub,
  git,
  gnutar,
  gzip,
  lib,
  llvmPackages_22,
  lua5_5,
  ninja,
  python3,
  replaceVars,
  stdenvNoCC,
  versionCheckHook,
  zstd,
}:
let
  inherit (lib)
    cmakeBool
    cmakeFeature
    licenses
    maintainers
    makeLibraryPath
    ;

  inherit (lib.fetchers)
    proxyImpureEnvVars
    ;

  clangTools =
    llvmPackages_22.clang-tools.override
      {
        enableLibcxx = true;
      };

  rstdSrc = fetchFromGitHub {
    owner = "litocpp";
    repo = "rstd";
    rev = "9cf950ecccb50b480ddeb51b7bcdf3b2141c9d89";
    hash = "sha256-oNSNNcVVnniJqsmMBYMuBJ2s24jwDK6qtKoDHFVLG2Q=";
  };

  luatoSrc = fetchFromGitHub {
    owner = "litocpp";
    repo = "luato";
    rev = "df0c6f2d1cce2051b4711d36067619eda7933683";
    hash = "sha256-XL1evcZbZJ2LfTi5T9UQ+4YBEw5YnDsGeY3IBS+Fs5U=";
  };

  licryptoSrc = fetchFromGitHub {
    owner = "litocpp";
    repo = "licrypto";
    rev = "40da005cbd7faf1328fd29a01cb0c534d6998612";
    hash = "sha256-Aussj13CS3lAIR0TmmU7NgVQg2l2QUdiNS47oa7Fcaw=";
  };
in
llvmPackages_22.libcxxStdenv.mkDerivation
  (finalAttrs: {
    pname = "lito";
    version = "0.8.7";

    src = fetchFromGitHub {
      owner = "litocpp";
      repo = "lito";
      tag = "v${finalAttrs.version}";
      hash = "sha256-2VWgxz5tbgzzCe7IvUYVPIg8kc9ydzvq33lmwl1Tuq4=";
    };

    patches = [
      (replaceVars ./depfile-store-roots.patch {
        storeDir = builtins.storeDir;
      })
    ];

    nativeBuildInputs = [
      cmake
      llvmPackages_22.lld
      llvmPackages_22.llvm
      ninja
    ];

    buildInputs = [
      lua5_5
      zstd
    ];

    # Keep source locations in diagnostics from retaining dependency sources.
    postUnpack = ''
      mkdir -p "$sourceRoot/deps"
      cp -R ${rstdSrc} "$sourceRoot/deps/rstd"
      cp -R ${luatoSrc} "$sourceRoot/deps/luato"
      cp -R ${licryptoSrc} "$sourceRoot/deps/licrypto"
      chmod -R u+w "$sourceRoot/deps"
    '';

    # Use nixpkgs' Lua 5.5 instead of downloading a particular patch release.
    postPatch = ''
      substituteInPlace deps/luato/src/lua/CMakeLists.txt \
        --replace-fail \
        "find_package(Lua 5.5.1 QUIET)" \
        "find_package(Lua 5.5 REQUIRED)"
    '';

    preConfigure = ''
      cmakeFlagsArray+=(
        "-DFETCHCONTENT_SOURCE_DIR_RSTD=$PWD/deps/rstd"
        "-DFETCHCONTENT_SOURCE_DIR_LUATO=$PWD/deps/luato"
        "-DFETCHCONTENT_SOURCE_DIR_LICRYPTO=$PWD/deps/licrypto"
      )
    '';

    cmakeFlags = [
      # Build-time helpers also need to locate the shared system libraries.
      (cmakeFeature "CMAKE_BUILD_RPATH" (
        makeLibraryPath finalAttrs.buildInputs
      ))
      (cmakeFeature "CMAKE_INSTALL_RPATH" (
        makeLibraryPath finalAttrs.buildInputs
      ))
      (cmakeFeature "CMAKE_CXX_COMPILER_CLANG_SCAN_DEPS" "${clangTools}/bin/clang-scan-deps")
      (cmakeBool "FETCHCONTENT_FULLY_DISCONNECTED" true)
      (cmakeBool "LITO_USE_SYSTEM_ZSTD" true)
    ];

    # Fortify wrappers become mangled C++ module symbols in rstd.
    hardeningDisable = [
      "fortify"
      "fortify3"
    ];

    doInstallCheck = true;

    nativeInstallCheckInputs = [
      versionCheckHook
    ];

    disallowedReferences = [
      rstdSrc
      luatoSrc
      licryptoSrc
    ];

    passthru = {
      fetchSourceBundle =
        {
          hash,
          pname,
          src,
          version,
        }:
        stdenvNoCC.mkDerivation {
          inherit
            src
            version
            ;

          pname = "${pname}-source-bundle";

          nativeBuildInputs = [
            cacert
            cargo
            cmake
            curl
            git
            gnutar
            gzip
            finalAttrs.finalPackage
            llvmPackages_22.clang
            llvmPackages_22.lld
            python3
          ];

          dontConfigure = true;

          buildPhase = ''
            runHook preBuild
            export HOME="$TMPDIR/home"
            export XDG_DATA_HOME="$TMPDIR/lito"
            mkdir -p "$HOME"
            # Lito needs an unlocked fetch to populate the offline registry cache.
            cp lito.lock "$TMPDIR/lito.lock"
            lito fetch --output bundle
            cmp lito.lock "$TMPDIR/lito.lock"
            # Git hook samples embed the build platform's shell store paths.
            # Keep only stable checkout metadata and locked registry releases.
            rm -rf bundle/v1/git/*/.git/{hooks,index,logs}
            python3 <<'PY'
            import json
            import tomllib
            from pathlib import Path

            with open("lito.lock", "rb") as lock_file:
                packages = tomllib.load(lock_file)["packages"]
            locked = {
                (package["source"].removeprefix("registry+"), package["name"]): package
                for package in packages
                if package.get("source", "").startswith("registry+")
            }
            for path in Path("bundle/v1/registry/index").glob("*/*.json"):
                cache = json.loads(path.read_text())
                package = locked[(cache["registry"], cache["package"])]
                body = json.loads(cache["body"])
                body["releases"] = [
                    release
                    for release in body["releases"]
                    if release["version"] == package["version"]
                ]
                assert len(body["releases"]) == 1, path
                assert body["releases"][0]["checksum"] == package["checksum"], path
                cache["body"] = json.dumps(body, sort_keys=True, separators=(",", ":"))
                cache["etag"] = None
                path.write_text(
                    json.dumps(cache, sort_keys=True, separators=(",", ":")) + "\n"
                )
            PY
            find bundle -exec touch -h -d @1 {} +
            tar \
              --sort=name \
              --mtime=@1 \
              --owner=0 \
              --group=0 \
              --numeric-owner \
              -cf - \
              -C bundle \
              . \
              | gzip -n > "$out"
            runHook postBuild
          '';

          dontInstall = true;
          dontFixup = true;

          impureEnvVars = proxyImpureEnvVars;

          outputHashMode = "flat";
          outputHashAlgo = "sha256";
          outputHash = hash;
        };
    };

    meta = {
      description = "Module-first C++ build tool";
      homepage = "https://github.com/litocpp/lito";
      license = with licenses; [
        mit
        asl20
      ];
      mainProgram = "lito";
      maintainers = with maintainers; [ brsvh ];
      platforms = [
        "aarch64-linux"
        "x86_64-linux"
      ];
    };
  })
