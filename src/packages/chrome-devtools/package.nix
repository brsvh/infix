{
  buildNpmPackage,
  chromium,
  fetchFromGitHub,
  lib,
  nodejs_24,
  npm-lockfile-fix,
  browser ? chromium,
  ...
}:
let
  inherit (lib)
    getExe
    intersectLists
    licenses
    maintainers
    ;

  devtoolsFrontend = fetchFromGitHub {
    owner = "ChromeDevTools";
    repo = "devtools-frontend";
    rev = "f22c645573adc85e4553747c577eebb874c3fb43";
    hash = "sha256-Lst8HJczmpxxN/0Q9cG+Pxzhz/C91dGUpxPr8N5XHDQ=";
  };
in
buildNpmPackage (finalAttrs: {
  pname = "chrome-devtools";
  version = "1.12.0";

  src = fetchFromGitHub {
    owner = "ChromeDevTools";
    repo = "chrome-devtools-mcp";
    tag = "chrome-devtools-mcp-v${finalAttrs.version}";
    hash = "sha256-VsjhByYciw/uTYRdWw3eJOdiKOLReY5LjZ7kPWCOzHU=";

    postFetch = ''
      ${getExe npm-lockfile-fix} "$out/package-lock.json"
    '';
  };

  nodejs = nodejs_24;
  npmDepsHash = "sha256-ZUJQSiR8UCs/0Y+Dk9hlAJUO+Dswn9wbDpUDI5re2ns=";
  npmBuildScript = "bundle";

  # Fetch the pinned submodule separately, without its Git history.
  postUnpack = ''
    cp -R ${devtoolsFrontend}/. "$sourceRoot/third_party/devtools-frontend"
    chmod -R u+w "$sourceRoot/third_party/devtools-frontend"
  '';

  patches = [
    ./browser-executable-path.patch
  ];

  env = {
    PUPPETEER_SKIP_DOWNLOAD = "true";
  };

  # npmConfigHook skips the root prepare script, which fixes trace-engine types.
  preBuild = ''
    node scripts/prepare.ts
    # Keep development dependencies during npm ci, then build release bundles.
    export NODE_ENV=production
  '';

  npmPackFlags = [
    "--ignore-scripts"
  ];

  # Updates are managed by Nix, not the upstream npm update checker.
  makeWrapperArgs = [
    "--set CHROME_DEVTOOLS_MCP_NO_UPDATE_CHECKS 1"
    "--set-default PUPPETEER_EXECUTABLE_PATH ${getExe browser}"
  ];

  doInstallCheck = true;

  installCheckPhase = ''
    runHook preInstallCheck

    for command in chrome-devtools chrome-devtools-mcp; do
      test -x "$out/bin/$command"
      PATH= "$out/bin/$command" --help > /dev/null
      test "$(PATH= "$out/bin/$command" --version)" = "${finalAttrs.version}"
    done

    runHook postInstallCheck
  '';

  meta = {
    changelog = "https://github.com/ChromeDevTools/chrome-devtools-mcp/releases/tag/chrome-devtools-mcp-v${finalAttrs.version}";
    description = "Chrome DevTools CLI and MCP server for coding agents";
    homepage = "https://github.com/ChromeDevTools/chrome-devtools-mcp";
    license = licenses.asl20;
    mainProgram = "chrome-devtools";
    maintainers = with maintainers; [ brsvh ];
    platforms = intersectLists nodejs_24.meta.platforms browser.meta.platforms;
  };
})
