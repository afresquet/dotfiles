{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.obsidian;
in
{
  options = {
    obsidian.enable = lib.mkEnableOption "Obsidian" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.obsidian ];

    allowedUnfree = [ "obsidian" ];
  };
}
