{
  autoPatchelfHook,
  cmake,
  fetchFromGitHub,
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
  version = "0.2.9";

  src = fetchFromGitHub {
    owner = "waywallen";
    repo = "waywallen-display";
    tag = "v${finalAttrs.version}";
    hash = "sha256-N+QjNfDu3RpfDWPE42miZ5i37CV68Y5A9EkzWUAolVI=";
  };

  postPatch = ''
    ui=extensions/kde/package/contents/ui
    cp "$ui/ImportTestEmbed.qml" "$ui/ImportTest.qml"
    cp "$ui/WaywallenSurfaceEmbed.qml" "$ui/WaywallenSurface.qml"
    rm "$ui/ImportTestEmbed.qml" "$ui/WaywallenSurfaceEmbed.qml"
  '';

  cmakeFlags = [
    (lib.cmakeBool "WAYWALLEN_DISPLAY_PLUGIN_QML" true)
    (lib.cmakeFeature "WAYWALLEN_DISPLAY_QML_URI" "Waywallen.DisplayEmbed")
  ];

  nativeBuildInputs = [
    autoPatchelfHook
    cmake
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
    qmlModule=$wallpapers/org.waywallen.kde/contents/ui
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
