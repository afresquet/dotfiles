# https://discourse.nixos.org/t/bambu-studio-any-working-method/62272/29
final: prev:
let
  desktopItem = prev.makeDesktopItem {
    name = "BambuStudio";
    desktopName = "Bambu Studio";
    exec = "bambu-studio %U";
    categories = [ "Graphics" "Utility" ];
    mimeTypes = [
      "x-scheme-handler/bambustudio"
      "model/3mf"
      "application/vnd.ms-3mfdocument"
      "application/prs.wavefront-obj"
      "application/x-amf"
    ];
  };

  app = prev.appimageTools.wrapType2 rec {
    name = "BambuStudio";
    pname = "bambu-studio";
    version = "02.04.00.70";
    ubuntu_version = "24.04_PR-8834";

    src = prev.fetchurl {
      url = "https://github.com/bambulab/BambuStudio/releases/download/v${version}/Bambu_Studio_ubuntu-${ubuntu_version}.AppImage";
      sha256 = "sha256:26bc07dccb04df2e462b1e03a3766509201c46e27312a15844f6f5d7fdf1debd";
    };

    profile = ''
      export SSL_CERT_FILE="${prev.cacert}/etc/ssl/certs/ca-bundle.crt"
      export GIO_MODULE_DIR="${prev.glib-networking}/lib/gio/modules/"
    '';

    extraPkgs =
      pkgs: with pkgs; [
        cacert
        glib
        glib-networking
        gst_all_1.gst-plugins-bad
        gst_all_1.gst-plugins-base
        gst_all_1.gst-plugins-good
        webkitgtk_4_1
      ];

  };
in
{
  # Keep the executable and its MakerWorld URI-handler desktop entry together
  # in one installable `bambu-studio` package.
  bambu-studio = prev.symlinkJoin {
    name = "BambuStudio";
    paths = [ app desktopItem ];
    meta = (app.meta or { }) // {
      mainProgram = "bambu-studio";
    };
  };
}
