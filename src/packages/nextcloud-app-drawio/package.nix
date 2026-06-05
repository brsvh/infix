{
  fetchNextcloudApp,
  ...
}:
let
  version = "4.2.3";
in
fetchNextcloudApp {
  appName = "drawio";
  appVersion = version;
  description = "Create and edit diagrams and whiteboards in Nextcloud";
  hash = "sha256-XLcDIcb7nr4oW7OtYC1FrF1lOsZTddhFT0HgjFsXXvg=";
  homepage = "https://github.com/jgraph/drawio-nextcloud";
  license = "agpl3Plus";
  url = "https://github.com/jgraph/drawio-nextcloud/releases/download/v${version}/drawio-v${version}.tar.gz";
}
