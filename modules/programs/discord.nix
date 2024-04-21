{ lib, config, pkgs, ... }: {
  options = {
    discord.enable = lib.mkEnableOption "Discord";
  };

  config = {
    packages = lib.mkIf config.discord.enable [
      pkgs.discord
    ];

    allowedUnfree = [
      "discord"
    ];
  };
}
