{
  autoPatchelfHook,
  cargo,
  cmake,
  fetchFromGitHub,
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
  lito,
  llvmPackages_22,
  ninja,
  pkg-config,
  protobuf,
  qt6,
  rustc,
  stdenvNoCC,
  vulkan-headers,
  vulkan-loader,
}:
let
  inherit (lib)
    licenses
    maintainers
    makeLibraryPath
    ;

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
llvmPackages_22.stdenv.mkDerivation (finalAttrs: {
  pname = "waywallen";
  version = "0.3.9";

  src = fetchFromGitHub {
    owner = "waywallen";
    repo = "waywallen";
    tag = "v${finalAttrs.version}";
    fetchLFS = true;
    hash = "sha256-mIO/9/U2nAiA0fEUEw2PBjFvo/j6AdzrC6TFx3hiou4=";
  };

  sourceBundle = lito.fetchSourceBundle {
    inherit (finalAttrs)
      pname
      src
      version
      ;

    hash = "sha256-b1aDG/iz+GV44kYbaQFwuffw4SSMPmr9s+63vx1AhDE=";
  };

  disallowedReferences = [
    finalAttrs.sourceBundle
    lito
  ];

  # Lito's C++ binaries lack the Nix runtime library search paths.
  nativeBuildInputs = [
    autoPatchelfHook
    cargo
    cmake
    git
    glslang
    gnutar
    gzip
    lito
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
    # Build from temporary sources so diagnostics do not retain the store cache.
    sourceBundleDir="$TMPDIR/lito-sources"
    mkdir -p "$sourceBundleDir"
    tar -xzf ${finalAttrs.sourceBundle} -C "$sourceBundleDir"
    ln -s "$sourceBundleDir/v1/cargo/"*/vendor "$sourceBundleDir/v1/cargo/vendor"
    lito build \
      --locked \
      --offline \
      --source-bundle "$sourceBundleDir" \
      --profile release \
      -j "$NIX_BUILD_CORES"
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    lito install \
      --locked \
      --offline \
      --source-bundle "$sourceBundleDir" \
      --profile release \
      --prefix "$out" \
      --force
    runHook postInstall
  '';

  qtWrapperArgs = [
    "--prefix"
    "LD_LIBRARY_PATH"
    ":"
    (makeLibraryPath [
      ffmpeg
      libpulseaudio
    ])
  ];

  meta = {
    inherit (lito.meta) platforms;

    description = "Wallpaper manager for Linux";
    homepage = "https://github.com/waywallen/waywallen";
    license = licenses.mit;
    mainProgram = "waywallen";
    maintainers = with maintainers; [ brsvh ];
  };
})
