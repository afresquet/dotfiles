{ lib, config, pkgs, ... }: {
  options = {
    vlc.enable = lib.mkEnableOption "VLC";
  };

  config = {
    packages = lib.mkIf config.vlc.enable [
      pkgs.vlc
    ];
  };
}
