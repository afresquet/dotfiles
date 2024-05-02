{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.discord;
in
{
  options = {
    discord.enable = lib.mkEnableOption "Discord" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      discord
      webcord
    ];

    allowedUnfree = [ "discord" ];
  };
}
