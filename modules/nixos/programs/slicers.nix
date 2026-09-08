{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.slicers;
in
{
  options = {
    slicers.enable = lib.mkEnableOption "3D Printer Slicers" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    xdg.mime.defaultApplications = {
      "x-scheme-handler/bambustudio" = "BambuStudio.desktop";
    };

    environment.systemPackages = with pkgs; [
      bambu-studio
      cura
      orca-slicer
      prusa-slicer
      openscad-unstable
    ];
  };
}
