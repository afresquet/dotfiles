{ lib, config, pkgs, ... }: {
  options = {
    file-manager.enable = lib.mkEnableOption "File Manager";
  };

  config = {
    file-manager.enable = lib.mkDefault true;

    packages = lib.mkIf config.file-manager.enable [
      pkgs.gnome.nautilus
    ];
  };
}
