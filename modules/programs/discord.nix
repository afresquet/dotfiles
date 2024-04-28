{ lib, config, pkgs, ... }: {
  options = {
    discord.enable = lib.mkEnableOption "Discord";
  };

  config = {
    packages = with pkgs; lib.mkIf config.discord.enable [
      discord
      webcord
    ];

    allowedUnfree = [
      "discord"
    ];
  };
}
