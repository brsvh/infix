{
  autoPatchelfHook,
  cmake,
  fetchFromGitHub,
  ffmpeg,
  glslang,
  lib,
  libgbm,
  libglvnd,
  libpulseaudio,
  libva,
  llvmPackages_22,
  ninja,
  pkg-config,
  protobuf,
  qt6,
  rustPlatform,
  vulkan-headers,
  vulkan-loader,
  ...
}:
let
  inherit (lib)
    licenses
    maintainers
    ;

  corrosionSrc = fetchFromGitHub {
    owner = "corrosion-rs";
    repo = "corrosion";
    rev = "1499b14e4906a2890f5cee1547c8848db261753d";
    hash = "sha256-ppuDNObfKhneD9AlnPAvyCRHKW3BidXKglD1j/LE9CM=";
  };

  ncrequestSrc = fetchFromGitHub {
    owner = "hypengw";
    repo = "ncrequest";
    rev = "37d3c588fb1307dd6c40fbc8681790b45eb5402a";
    hash = "sha256-j18+Pwr7Kj1VdgjmsLsn1HIg2lF6dXj2N5up9ymcnNQ=";
  };

  qextraSrc = fetchFromGitHub {
    owner = "hypengw";
    repo = "QExtra";
    rev = "2106172c8c55693248661f5ddfc0623ff489285d";
    hash = "sha256-vxe4mrK6lq6hhniU5gTqpJ9AX9JHUruZ5RXPOnp/gPc=";
  };

  qmlMaterialSrc = fetchFromGitHub {
    owner = "hypengw";
    repo = "QmlMaterial";
    rev = "628f580b60f8e7195447ec9e27dae5cce5b0fcbc";
    fetchLFS = true;
    hash = "sha256-38/aUJLAtlccVc9rO2f/gDkCXfu/Pf8c3YTXv39w2+o=";
  };

  rstdSrc = fetchFromGitHub {
    owner = "litocpp";
    repo = "rstd";
    rev = "bf5f855ddb1b84390306e0913b89149ac72a3510";
    hash = "sha256-/O6FK7m+JE897j3IHWWnyIuxeQPzkg6Uz0LaYeydIHY=";
  };

  vmaSrc = fetchFromGitHub {
    owner = "GPUOpen-LibrariesAndSDKs";
    repo = "VulkanMemoryAllocator";
    rev = "3aa921224c154a0d2c43912bc88e1c42ce1f7607";
    hash = "sha256-LBZJcom7G7maF9wpUVeVEJQAJwGy6365INk3VD0/0PM=";
  };

  vvkSrc = fetchFromGitHub {
    owner = "litocpp";
    repo = "vvk";
    rev = "8fcfd34b43a13ade515f029b0b4209bd3684645f";
    hash = "sha256-vmS1xQ3oE2CLZtytkvrcJIoKBxp8gS5fxzqL5pbeiDY=";
  };

  wavsenSrc = fetchFromGitHub {
    owner = "hypengw";
    repo = "wavsen";
    rev = "e49fc62fdc1b57abeabb643daa6ebab96fb3821f";
    hash = "sha256-TWceTw1Oxgk5TD7RoRB+aA49dgZbweZJpEXFQAVlaX0=";
  };
in
(rustPlatform.buildRustPackage.override {
  stdenv = llvmPackages_22.stdenv;
})
  (finalAttrs: {
    pname = "waywallen";
    version = "0.2.6";

    src = fetchFromGitHub {
      owner = "waywallen";
      repo = "waywallen";
      tag = "v${finalAttrs.version}";
      fetchLFS = true;
      hash = "sha256-I8+NlqzHq/pJ75wsI0po1mahRBdGdw96ptVRt9H/Ip0=";
    };

    cargoHash = "sha256-M6LQixcLvub3QpFPrYS5Cc63AYQ7xLJoMvpuhKonbT4=";

    postPatch = ''
      # QML language-server metadata writes into read-only dependency sources.
      substituteInPlace ui/CMakeLists.txt \
        --replace-fail \
          "set(QT_QML_GENERATE_QMLLS_INI ON)" \
          "set(QT_QML_GENERATE_QMLLS_INI OFF)"
    '';

    configurePhase = "cmakeConfigurePhase";

    # Fortify wrappers become mangled C++ module symbols in rstd.
    hardeningDisable = [
      "fortify"
      "fortify3"
    ];

    cmakeFlags = [
      "-DCMAKE_CXX_COMPILER_CLANG_SCAN_DEPS=${lib.getExe' llvmPackages_22.clang-tools "clang-scan-deps"}"
      "-DCMAKE_LINKER_TYPE=LLD"
      "-DCMAKE_MODULE_PATH=${qt6.qtgrpc}/lib/cmake/Qt6"
      "-DProtobuf_ROOT=${protobuf}"
      "-DQT_INSTALL_QML=lib/qt-6/qml"
      "-DFETCHDEPS_LOCAL_Corrosion=${corrosionSrc}"
      "-DFETCHDEPS_LOCAL_QExtra=${qextraSrc}"
      "-DFETCHDEPS_LOCAL_ncrequest=${ncrequestSrc}"
      "-DFETCHDEPS_LOCAL_qml_material=${qmlMaterialSrc}"
      "-DFETCHDEPS_LOCAL_rstd=${rstdSrc}"
      "-DFETCHDEPS_LOCAL_vma=${vmaSrc}"
      "-DFETCHDEPS_LOCAL_vvk=${vvkSrc}"
      "-DFETCHDEPS_LOCAL_wavsen=${wavsenSrc}"
      "-DWAYWALLEN_CARGO_OFFLINE=ON"
    ];

    nativeBuildInputs = [
      autoPatchelfHook
      cmake
      glslang
      llvmPackages_22.clang-tools
      llvmPackages_22.lld
      ninja
      pkg-config
      protobuf
      qt6.wrapQtAppsHook
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

    qtWrapperArgs = [
      "--prefix"
      "LD_LIBRARY_PATH"
      ":"
      (lib.makeLibraryPath [
        ffmpeg
        libpulseaudio
      ])
    ];

    doCheck = false;

    meta = {
      description = "Wallpaper manager for Linux";
      homepage = "https://github.com/waywallen/waywallen";
      license = licenses.mit;
      mainProgram = "waywallen";
      maintainers = with maintainers; [ brsvh ];
      platforms = lib.platforms.linux;
    };
  })
