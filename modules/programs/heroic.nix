{ lib, config, pkgs, ... }: {
  options = {
    heroic.enable = lib.mkEnableOption "Heroic Launcher";
  };

  config = {
    packages = lib.mkIf config.heroic.enable [
      pkgs.heroic
    ];
  };
}
