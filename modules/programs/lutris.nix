{ lib, config, pkgs, ... }: {
  options = {
    lutris.enable = lib.mkEnableOption "Lutris";
  };

  config = {
    packages = lib.mkIf config.lutris.enable [
      pkgs.lutris
    ];
  };
}
