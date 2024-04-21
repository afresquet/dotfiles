{ lib, config, pkgs, ... }: {
  options = {
    vlc.enable = lib.mkEnableOption "VLC";
  };

  config = {
    vlc.enable = lib.mkDefault true;

    packages = lib.mkIf config.vlc.enable [
      pkgs.vlc
    ];
  };
}
