{
  fetchFromGitHub,
  lib,
  stdenvNoCC,
  ...
}:

stdenvNoCC.mkDerivation {
  pname = "rime-frost";
  version = "unstable-2026-06-10";

  src = fetchFromGitHub {
    owner = "gaboolic";
    repo = "rime-frost";
    rev = "fc6e441a4859ef949df66433b7508eaeeb56caf5";
    hash = "sha256-+C+sodPaO6oeTWhHgkknHvQ1ll52j8PdPAn7zu9I0y0=";
  };

  installPhase = ''
    runHook preInstall

    rm -rf .github .git* others README.md

    mv default.yaml rime_frost_suggestion.yaml

    mkdir -p $out/share
    cp -r . $out/share/rime-data

    runHook postInstall
  '';

  meta = {
    description = "Rime schema with curated Chinese dictionaries and pinyin layouts";

    longDescription = ''
      Rime Frost (白霜拼音) provides ready-to-use Rime schemas, dictionaries,
      Lua helpers, OpenCC data, and a compact grammar model for Simplified
      Chinese input. It includes full Pinyin, several Double Pinyin layouts,
      T9 Pinyin, Wubi86, and Moqi single-character auxiliary-code schemas.

      To enable the upstream default schema list from this package, include
      the renamed default configuration from your `default.custom.yaml`:

      ```yaml
      patch:
        __include: rime_frost_suggestion:/
      ```
    '';

    homepage = "https://github.com/gaboolic/rime-frost";
    changelog = "https://github.com/gaboolic/rime-frost/blob/master/others/CHANGELOG.md";
    license = lib.licenses.gpl3Only;
    maintainers = with lib.maintainers; [ brsvh ];
  };
}
