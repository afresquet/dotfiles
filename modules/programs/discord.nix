{ lib, config, pkgs, ... }: {
  options = {
    discord.enable = lib.mkEnableOption "Discord";
  };

  config = {
    discord.enable = lib.mkDefault true;

    packages = lib.mkIf config.discord.enable [
      pkgs.discord
    ];

    allowedUnfree = [
      "discord"
    ];
  };
}
