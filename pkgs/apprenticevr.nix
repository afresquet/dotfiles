{
  lib,
  stdenv,
  fetchurl,
  makeDesktopItem,
  appimageTools,
  undmg,
  ...
}:
let
  pname = "apprenticevr";
  version = "2.3.6";
  repo = "KaladinDMP/apprenticeVrSrc";

  sources = {
    "x86_64-linux" = {
      url = "https://github.com/${repo}/releases/download/v${version}/apprenticevr-${version}-x86_64.AppImage";
      hash = "sha256-ft320DLpPzqo5k59CJAacvbuRqS+7/id40z+GKWqH0Y=";
    };
    "aarch64-linux" = {
      url = "https://github.com/${repo}/releases/download/v${version}/apprenticevr-${version}-arm64.AppImage";
      hash = "sha256-ffPltsRZ6L/e+IzgZrg6RNpc+smrjp/I+WfcPLpsVFA=";
    };
    "x86_64-darwin" = {
      url = "https://github.com/${repo}/releases/download/v${version}/apprenticevr-${version}-x64.dmg";
      hash = "sha256-WiaC37JbI1iP8EebPCbfK+oa/je8DnXXFMpMUgZ/eaY=";
    };
    "aarch64-darwin" = {
      url = "https://github.com/${repo}/releases/download/v${version}/apprenticevr-${version}-arm64.dmg";
      hash = "sha256-Wst1Z+SjIqWm25RjhYQW2ew6bFXECr/t+6Qf04bXpzU=";
    };
  };

  source = sources.${stdenv.hostPlatform.system} or (throw "apprenticevr: unsupported system ${stdenv.hostPlatform.system}");

  src = fetchurl source;

  meta = with lib; {
    description = "Sideload apps to your Meta Quest";
    homepage = "https://github.com/${repo}";
    changelog = "https://github.com/${repo}/releases/tag/v${version}";
    license = licenses.mit;
    platforms = builtins.attrNames sources;
    mainProgram = pname;
  };
in
if stdenv.hostPlatform.isDarwin then
  stdenv.mkDerivation {
    inherit pname version src meta;

    nativeBuildInputs = [ undmg ];

    sourceRoot = ".";

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/Applications"
      cp -r *.app "$out/Applications/"
      runHook postInstall
    '';
  }
else
  appimageTools.wrapType2 {
    inherit pname version src meta;

    desktopItems = [
      (makeDesktopItem {
        name = pname;
        exec = pname;
        terminal = false;
        desktopName = "ApprenticeVR";
        comment = meta.description;
        categories = [ "Utility" ];
      })
    ];
  }
