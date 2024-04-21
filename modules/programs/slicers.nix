{ lib, config, pkgs, ... }: {
  options = {
    slicers.enable = lib.mkEnableOption "3D Printer Slicers";
  };

  config = {
    packages = with pkgs; lib.mkIf config.slicers.enable [
      cura
      prusa-slicer
    ];
  };
}
