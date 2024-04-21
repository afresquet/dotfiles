{ lib, config, pkgs, ... }: {
  options = {
    obsidian.enable = lib.mkEnableOption "Obsidian";
  };

  config = {
    packages = lib.mkIf config.discord.enable [
      pkgs.obsidian
    ];

    allowedUnfree = [
      "obsidian"
    ];
  };
}
