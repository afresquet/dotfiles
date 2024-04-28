{ lib, config, pkgs, ... }: {
  options = {
    brave.enable = lib.mkEnableOption "Brave Browser";
  };

  config = {
    packages = lib.mkIf config.brave.enable [
      pkgs.brave
    ];
  };
}
