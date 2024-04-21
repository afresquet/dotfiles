{ lib, config, pkgs, ... }: {
  options = {
    minecraft.enable = lib.mkEnableOption "Minecraft";
  };

  config = {
    packages = lib.mkIf config.minecraft.enable [
      pkgs.prismlauncher
    ];
  };
}
