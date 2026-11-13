{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.minecraft;
in
{
  options = {
    minecraft.enable = lib.mkEnableOption "Minecraft" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable { environment.systemPackages = [ pkgs.prismlauncher ]; };
}
