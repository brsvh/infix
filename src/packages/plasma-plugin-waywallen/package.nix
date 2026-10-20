{
  autoPatchelfHook,
  cmake,
  fetchFromGitHub,
  gettext,
  lib,
  libglvnd,
  ninja,
  pkg-config,
  qt6,
  stdenv,
  unzip,
  vulkan-headers,
  vulkan-loader,
  ...
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "plasma-plugin-waywallen";
  version = "0.4.3";

  src = fetchFromGitHub {
    owner = "waywallen";
    repo = "waywallen-display";
    tag = "v${finalAttrs.version}";
    hash = "sha256-pYc7n+FB3Y3BHP+bkExhqZWXZPUEXbNcTYFQIj+rBS4=";
  };

  cmakeFlags = [
    (lib.cmakeBool "WAYWALLEN_DISPLAY_PLUGIN_QML" true)
    (lib.cmakeFeature "WAYWALLEN_DISPLAY_QML_URI" "Waywallen.DisplayEmbed")
  ];

  nativeBuildInputs = [
    autoPatchelfHook
    cmake
    gettext
    ninja
    pkg-config
    unzip
  ];

  runtimeDependencies = [
    libglvnd
    vulkan-loader
  ];

  appendRunpaths = [
    (lib.makeLibraryPath finalAttrs.runtimeDependencies)
  ];

  buildInputs = [
    qt6.qtbase
    qt6.qtdeclarative
    vulkan-headers
  ]
  ++ finalAttrs.runtimeDependencies;

  dontWrapQtApps = true;

  # Test setup is inside assert(), which is compiled out in Release builds.
  doCheck = false;

  buildPhase = ''
    runHook preBuild
    cmake --build . --target package
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    archives=(waywallen-kde-*-embed.zip)
    (( ''${#archives[@]} == 1 ))
    wallpapers=$out/share/plasma/wallpapers
    qmlModule=$wallpapers/org.waywallen.kde/contents/ui/Plugin
    qmlModule=$qmlModule/WaywallenDisplayEmbed
    install -d "$wallpapers"
    unzip -q "''${archives[0]}" -d "$wallpapers"
    rm "$qmlModule/"*_qml_module_dir_map.qrc
    runHook postInstall
  '';

  meta = {
    description = "Plasma 6 wallpaper plugin for the Waywallen daemon";
    homepage = "https://github.com/waywallen/waywallen-display";
    license = with lib.licenses; [
      gpl2Plus
      mit
    ];
    maintainers = with lib.maintainers; [ brsvh ];
    platforms = lib.platforms.linux;
  };
})
