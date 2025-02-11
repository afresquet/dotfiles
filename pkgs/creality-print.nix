{
  lib,
  fetchurl,
  makeDesktopItem,
  appimageTools,
  ...
}:
let
  releaseNotesVersion = "4.3.7";
in
appimageTools.wrapType2 rec {
  pname = "creality-print";
  version = "4.3.7.6627";

  src = fetchurl {
    url = "https://file2-cdn.creality.com/file/05a4538e0c7222ce547eb8d58ef0251e/Creality_Print-v${version}-x86_64-Release.AppImage";
    hash = "sha256-WUsL7UbxSY94H4F1Ww8vLsfRyeg2/DZ+V4B6eH3M6+M=";
  };

  desktopItems = [
    (makeDesktopItem {
      name = "creality-print";
      exec = "creality-print";
      terminal = false;
      desktopName = "Creality Print";
      comment = meta.description;
      categories = [ "Utility" ];
    })
  ];

  meta = with lib; {
    description = "Creality 3D Printing Slicing Software";
    homepage = "https://www.creality.com";
    changelog = "https://github.com/CrealityOfficial/CrealityPrint/releases/tag/v${releaseNotesVersion}";
    license = licenses.gpl3Only;
    platforms = platforms.linux;
    mainProgram = "creality-print";
  };
}
