{
  fetchgit,
  knockknock,
  lib,
  mu4e,
  trivialBuild,
  ...
}:
let
  inherit (lib)
    licenses
    maintainers
    ;

  version = "0.1.0";

  src = fetchgit {
    url = "https://codeberg.org/bingshan/emacs-mu4e-knockknock";
    rev = "af5916500a0f0e636d8bd52513f947189fffbf9a";
    hash = "sha256-NveA3cqDpfZOUa8Z2bYgAbQnmQrWIoZ+HojGMhMXQdk=";
  };

  meta = {
    description = "Knockknock notifications for mu4e";
    homepage = "https://codeberg.org/bingshan/emacs-mu4e-knockknock";
    license = licenses.gpl3Plus;
    maintainers = with maintainers; [ brsvh ];
  };
in
trivialBuild rec {
  inherit
    meta
    src
    version
    ;

  pname = "mu4e-knockknock";

  buildInputs = propagatedUserEnvPkgs;

  propagatedUserEnvPkgs = [
    knockknock
    mu4e
  ];
}
