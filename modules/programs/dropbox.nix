{ lib, config, pkgs, ... }: {
  options = {
    dropbox.enable = lib.mkEnableOption "Dropbox";
  };

  config = {
    packages = lib.mkIf config.dropbox.enable [
      pkgs.maestral
    ];
  };
}
