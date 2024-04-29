{ lib, config, pkgs, ... }: {
  options = {
    rofi.enable = lib.mkEnableOption "rofi";
  };

  config = {
    programs.rofi = {
      enable = config.rofi.enable;
      package = pkgs.rofi-wayland;
    };
  };
}
