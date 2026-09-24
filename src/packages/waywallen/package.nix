{
  autoPatchelfHook,
  cacert,
  cargo,
  cmake,
  curl,
  fetchFromGitHub,
  fetchurl,
  ffmpeg,
  git,
  glslang,
  gnutar,
  gzip,
  lib,
  libgbm,
  libglvnd,
  libpulseaudio,
  libva,
  llvmPackages_22,
  ninja,
  pkg-config,
  protobuf,
  python3,
  qt6,
  rustc,
  stdenvNoCC,
  vulkan-headers,
  vulkan-loader,
  writeText,
}:
let
  inherit (lib)
    licenses
    maintainers
    ;

  version = "0.3.9";
  litoVersion = "0.8.1";

  litoReleases = {
    aarch64-linux = {
      arch = "aarch64";
      hash = "sha256-Hrc5La3kHDuClkg4jDM3RTsoU19J1lxhdEIw5eDMI6E=";
    };
    x86_64-linux = {
      arch = "x86_64";
      hash = "sha256-m/LaN9Lu2VO1OZXZputEDTILjlcAfud50IADQM3kerc=";
    };
  };

  litoRelease =
    litoReleases.${stdenvNoCC.hostPlatform.system}
      or (throw "lito: unsupported system ${stdenvNoCC.hostPlatform.system}");

  lito = stdenvNoCC.mkDerivation {
    pname = "lito";
    version = litoVersion;

    src = fetchurl {
      url = "https://github.com/litocpp/lito/releases/download/v${litoVersion}/lito-v${litoVersion}-linux-${litoRelease.arch}.tar.gz";
      inherit (litoRelease) hash;
    };

    nativeBuildInputs = [
      autoPatchelfHook
    ];

    buildInputs = [
      llvmPackages_22.libcxx
    ];

    installPhase = ''
      runHook preInstall
      cp -R . "$out"
      runHook postInstall
    '';
  };

  litoSrc = fetchFromGitHub {
    owner = "litocpp";
    repo = "lito";
    tag = "v${litoVersion}";
    hash = "sha256-6A39ta0iMgWyvuteMYD+z56r4+1wBKbUXwEh8o5Gqig=";
  };

  litoQt = stdenvNoCC.mkDerivation {
    pname = "lito-qt";
    version = "0.1.0";

    src = "${litoSrc}/data/script-packages/qt";

    postPatch = ''
      substituteInPlace qt/moc.lua \
        --replace-fail \
        $'  for _, value in ipairs(environment.framework_include_directories or {}) do\n    append(result, value)\n  end\n  return result' \
        $'  for _, value in ipairs(environment.framework_include_directories or {}) do\n    append(result, value)\n  end\n  append(result, "/nix/store")\n  return result'
    '';

    dontConfigure = true;
    dontBuild = true;
    dontFixup = true;

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -R . "$out"
      runHook postInstall
    '';
  };

  litoConfig = writeText "waywallen-lito-config.toml" ''
    [builtin.packages]
    qt = { path = "${litoQt}" }
  '';

  waywallenSrc = fetchFromGitHub {
    owner = "waywallen";
    repo = "waywallen";
    tag = "v${version}";
    fetchLFS = true;
    hash = "sha256-mIO/9/U2nAiA0fEUEw2PBjFvo/j6AdzrC6TFx3hiou4=";
  };

  sourceBundle = stdenvNoCC.mkDerivation {
    pname = "waywallen-source-bundle";
    inherit version;

    src = waywallenSrc;

    nativeBuildInputs = [
      lito
      cacert
      cargo
      cmake
      curl
      git
      gnutar
      gzip
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
      # Drop mutable checkout metadata and registry releases outside the lockfile.
      rm -rf bundle/v1/git/*/.git/index bundle/v1/git/*/.git/logs
      python3 - <<'PYTHON'
      import json
      from pathlib import Path
      import tomllib

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
              release for release in body["releases"]
              if release["version"] == package["version"]
          ]
          assert len(body["releases"]) == 1, path
          assert body["releases"][0]["checksum"] == package["checksum"], path
          cache["body"] = json.dumps(body, sort_keys=True, separators=(",", ":"))
          cache["etag"] = None
          path.write_text(json.dumps(cache, sort_keys=True, separators=(",", ":")) + "\n")
      PYTHON
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

    installPhase = "true";

    outputHashMode = "flat";
    outputHashAlgo = "sha256";
    outputHash = "sha256-Oo6n54LfSznuLsZbdKj0oNDiXqeVdeyujNs4WAOX9L8=";
  };

  sourceBundleDir = stdenvNoCC.mkDerivation {
    pname = "waywallen-source-bundle";
    inherit version;

    src = sourceBundle;

    nativeBuildInputs = [
      gnutar
      gzip
    ];

    dontUnpack = true;
    dontFixup = true;

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      tar -xzf "$src" -C "$out"
      ln -s "$out/v1/cargo/"*/vendor "$out/v1/cargo/vendor"
      runHook postInstall
    '';
  };

  wrapProtocConfig = stdenvNoCC.mkDerivation {
    pname = "wrap-protoc-config";
    version = qt6.qtgrpc.version;

    dontUnpack = true;

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/lib/cmake/WrapProtoc"
      cp \
        ${qt6.qtgrpc}/lib/cmake/Qt6/FindWrapProtoc.cmake \
        "$out/lib/cmake/WrapProtoc/WrapProtocConfig.cmake"
      runHook postInstall
    '';
  };
in
llvmPackages_22.stdenv.mkDerivation {
  pname = "waywallen";
  inherit version;

  src = waywallenSrc;

  postPatch = ''
    mkdir -p .lito
    cp ${litoConfig} .lito/config.toml
  '';

  # Lito's C++ binaries lack the Nix runtime library search paths.
  nativeBuildInputs = [
    autoPatchelfHook
    lito
    cargo
    cmake
    glslang
    gnutar
    git
    llvmPackages_22.clang-tools
    llvmPackages_22.lld
    llvmPackages_22.llvm
    ninja
    pkg-config
    protobuf
    qt6.qttools
    qt6.wrapQtAppsHook
    rustc
    wrapProtocConfig
  ];

  buildInputs = [
    ffmpeg
    libgbm
    libglvnd
    libpulseaudio
    libva
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtgrpc
    qt6.qtshadertools
    qt6.qtwayland
    qt6.qtwebsockets
    vulkan-headers
    vulkan-loader
  ];

  # Fortify wrappers become mangled C++ module symbols in rstd.
  hardeningDisable = [
    "fortify"
    "fortify3"
  ];

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild
    export HOME="$TMPDIR/home"
    export XDG_DATA_HOME="$TMPDIR/lito"
    mkdir -p "$HOME"
    git config --global --add safe.directory '*'
    lito build \
      --locked \
      --offline \
      --source-bundle ${sourceBundleDir} \
      --profile release \
      -j "$NIX_BUILD_CORES"
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    lito install \
      --locked \
      --offline \
      --source-bundle ${sourceBundleDir} \
      --profile release \
      --prefix "$out" \
      --force
    runHook postInstall
  '';

  qtWrapperArgs = [
    "--prefix"
    "LD_LIBRARY_PATH"
    ":"
    (lib.makeLibraryPath [
      ffmpeg
      libpulseaudio
    ])
  ];

  meta = {
    description = "Wallpaper manager for Linux";
    homepage = "https://github.com/waywallen/waywallen";
    license = licenses.mit;
    mainProgram = "waywallen";
    maintainers = with maintainers; [ brsvh ];
    platforms = builtins.attrNames litoReleases;
  };
}
