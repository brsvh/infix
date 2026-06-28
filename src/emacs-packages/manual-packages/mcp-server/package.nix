{
  fetchgit,
  lib,
  melpaBuild,
  ...
}:
let
  inherit (lib)
    licenses
    maintainers
    ;

  version = "0.7.0";

  src = fetchgit {
    url = "https://github.com/rhblind/emacs-mcp-server.git";
    rev = "a5d749cf9880598f66308545985526fd4460627f";
    hash = "sha256-ugaOqSnphgUKVm0+sem6oNthOFHIB5uIpksyTuGSsxE=";
  };

  meta = {
    description = "Pure Elisp MCP server for GNU Emacs";
    homepage = "https://github.com/rhblind/emacs-mcp-server";
    license = licenses.gpl3Plus;
    maintainers = with maintainers; [ brsvh ];
  };
in
melpaBuild {
  inherit
    meta
    src
    version
    ;

  pname = "mcp-server";

  files = ''(:defaults "tools/*.el" "mcp-wrapper.py" "mcp-wrapper.sh")'';

  packageRequires = [ ];
}
