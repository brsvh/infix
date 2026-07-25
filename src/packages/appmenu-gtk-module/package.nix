{
  fetchFromGitLab,
  glib,
  gtk2,
  gtk3,
  lib,
  meson,
  ninja,
  pkg-config,
  stdenv,
  ...
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "appmenu-gtk-module";
  version = "25.04";

  src = fetchFromGitLab {
    owner = "vala-panel-project";
    repo = "vala-panel-appmenu";
    tag = finalAttrs.version;
    hash = "sha256-v5J3nwViNiSKRPdJr+lhNUdKaPG82fShPDlnmix5tlY=";
  };

  sourceRoot = "source/subprojects/appmenu-gtk-module";

  # Install into this derivation instead of GTK's immutable store path.
  postPatch = ''
    substituteInPlace src/gtk-2.0/meson.build \
      --replace-fail "gtk2.get_variable(pkgconfig:'libdir')" "get_option('libdir')"

    substituteInPlace src/gtk-3.0/meson.build \
      --replace-fail "gtk3.get_variable(pkgconfig:'libdir')" "get_option('libdir')"
  '';

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
  ];

  propagatedBuildInputs = [
    glib
    gtk2
    gtk3
  ];

  meta = {
    description = "GTK modules that export application menus over D-Bus";
    homepage = "https://gitlab.com/vala-panel-project/vala-panel-appmenu/-/tree/${finalAttrs.version}/subprojects/appmenu-gtk-module";
    license = lib.licenses.lgpl3Only;
    maintainers = with lib.maintainers; [ brsvh ];
    platforms = lib.platforms.linux;
  };
})
