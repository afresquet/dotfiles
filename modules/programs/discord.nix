{ lib, config, pkgs, commonUtils, ... }: {
  options = {
    discord.enable = lib.mkEnableOption "Discord";
  };

  config = {
    packages = lib.mkIf config.discord.enable [
      (commonUtils.waylandWrapper {
        name = "discord";
        inherit pkgs lib;
      })
      pkgs.webcord
    ];

    allowedUnfree = [
      "discord"
    ];
  };
}
