{ lib, config, pkgs, ... }: {
  options = {
    bottles.enable = lib.mkEnableOption "Bottles";
  };

  config = {
    packages = lib.mkIf config.bottles.enable [
      pkgs.bottles
    ];
  };
}
