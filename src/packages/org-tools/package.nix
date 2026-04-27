{
  lib,
  fetchFromGitHub,
  rustPlatform,
  ...
}:
let
  inherit (lib)
    licenses
    maintainers
    ;
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "org-tools";
  version = "0.1.4";

  src = fetchFromGitHub {
    owner = "lino";
    repo = "org-tools";
    rev = "v${finalAttrs.version}";
    hash = "sha256-EyfL/vs0o3MG3OwJCQwd+CLLn2drV6Vdm5tslk0ajSk=";
  };

  cargoHash = "sha256-vIj2y2qdMyPvWYkakXddR8jsLtmr8Hx3OnMVb59ar8M=";

  meta = {
    description = "Implementation of some things org-mode in rust";
    homepage = "https://github.com/lino/org-tools";
    license = licenses.gpl3Plus;
    maintainers = with maintainers; [ brsvh ];
  };
})
