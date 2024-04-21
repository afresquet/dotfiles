{ lib, config, ... }: {
  options = {
    steam.enable = lib.mkEnableOption "Steam";
  };

  config = {
    programs.steam = {
      enable = config.steam.enable;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
    };

    allowedUnfree = [
      "steam"
      "steam-original"
      "steam-run"
    ];
  };
}
