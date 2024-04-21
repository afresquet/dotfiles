{ lib, config, pkgs, ... }: {
  options = {
    brave.enable = lib.mkEnableOption "Brave Browser";
  };

  config = {
    brave.enable = lib.mkDefault true;

    packages = lib.mkIf config.brave.enable [
      pkgs.brave
    ];
  };
}
