{ lib, config, pkgs, ... }: {
  options = {
    dropbox.enable = lib.mkEnableOption "Dropbox";
  };

  config = {
    dropbox.enable = lib.mkDefault true;

    packages = lib.mkIf config.dropbox.enable [
      pkgs.maestral
    ];
  };
}
