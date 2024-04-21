{ lib, config, pkgs, ... }: {
  options = {
    file-manager.enable = lib.mkEnableOption "File Manager";
  };

  config = {
    packages = lib.mkIf config.file-manager.enable [
      pkgs.gnome.nautilus
    ];
  };
}
