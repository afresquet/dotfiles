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
    environment.systemPackages = with pkgs; [
      cura
      orca-slicer
      prusa-slicer
    ];
  };
}
