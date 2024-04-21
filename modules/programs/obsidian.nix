{ lib, config, pkgs, ... }: {
  options = {
    obsidian.enable = lib.mkEnableOption "Obsidian";
  };

  config = {
    obsidian.enable = lib.mkDefault true;

    packages = lib.mkIf config.discord.enable [
      pkgs.obsidian
    ];

    allowedUnfree = [
      "obsidian"
    ];
  };
}
