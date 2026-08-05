{
  bison,
  coreutils,
  fetchurl,
  flex,
  lib,
  libxcrypt,
  perl,
  stdenv,
  ...
}:
let
  inherit (lib)
    getExe'
    licenses
    maintainers
    ;

  perlWithTls = perl.withPackages (perlPackages: [
    perlPackages.IOSocketSSL
  ]);
in
stdenv.mkDerivation (finalAttrs: {
  pname = "inn";
  version = "2.7.4";

  src = fetchurl {
    url = "https://downloads.isc.org/isc/inn/inn-${finalAttrs.version}.tar.gz";
    hash = "sha256-gPx+gB4ZlssXu0MNEE3ZxbKapXH9SympyCG0+tsFHTs=";
  };

  patches = [
    ./credential-files.patch
    ./inncheck-never.patch
  ];

  configureFlags = [
    "--disable-setgid-inews"
    "--disable-uucp-rnews"
    "--enable-largefiles"
    "--with-sendmail=${getExe' coreutils "false"}"
    "--without-bdb"
    "--without-blocklist"
    "--without-canlock"
    "--without-krb5"
    "--without-openssl"
    "--without-perl"
    "--without-python"
    "--without-sasl"
    "--without-sqlite3"
    "--without-zlib"
  ];

  nativeBuildInputs = [
    bison
    flex
    perlWithTls
  ];

  buildInputs = [
    libxcrypt
  ];

  installFlags = [
    "OWNER="
    "ROWNER="
  ];

  postInstall = ''
    patchShebangs "$out/bin"
  '';

  meta = {
    description = "Complete Usenet news system";
    homepage = "https://www.eyrie.org/~eagle/software/inn/";
    license = licenses.isc;
    mainProgram = "innd";
    maintainers = with maintainers; [ brsvh ];
    platforms = lib.platforms.unix;
  };
})
