{
  lib,
  fetchurl,
  makeDesktopItem,
  appimageTools,
  ...
}:
let
  pname = "cura";
  version = "5.7.1";
  description = "Ultimaker Cura Printing Slicing Software";
in
appimageTools.wrapType2 {
  inherit pname version;

  src = fetchurl {
    url = "https://github.com/Ultimaker/Cura/releases/download/${version}/UltiMaker-Cura-${version}-linux-X64.AppImage";
    hash = "sha256-LZMD0fo8TSlDEJspvTka724lYq5EgrOlDkwMktXqATw=";
  };

  desktopItems = [
    (makeDesktopItem {
      name = pname;
      exec = pname;
      terminal = false;
      desktopName = "Ultimaker Cura";
      comment = description;
      categories = [ "Utility" ];
    })
  ];

  meta = {
    inherit description;
    homepage = "https://ultimaker.com/es/software/ultimaker-cura/";
    changelog = "https://github.com/Ultimaker/Cura/releases/tag/${version}";
    license = lib.licenses.lgpl3Plus;
    platforms = lib.platforms.linux;
    mainProgram = pname;
  };
}
