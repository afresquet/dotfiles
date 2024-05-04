{ utils, ... }:
let
  cliModules = utils.importDirAsAttrSet { dir = ./.; };
  defaultModule = {
    default =
      { pkgs, ... }:
      {
        imports = utils.importDir ./.;

        home.packages = with pkgs; [
          fd
          tokei
          uutils-coreutils
          wget
          wiki-tui
          youtube-dl
          grex
          # archives
          zip
          xz
          unzip
          p7zip
        ];
      };
  };
in
cliModules // defaultModule
