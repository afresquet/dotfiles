{ lib, config, ... }: {
  options = {
    obs-studio.enable = lib.mkEnableOption "OBS Studio";
  };

  config = {
    programs.obs-studio = {
      enable = config.obs-studio.enable;
    };
  };
}
