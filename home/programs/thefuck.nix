{ lib, config, ... }: {
  options = {
    thefuck.enable = lib.mkEnableOption "thefuck";
  };

  config = {
    programs.thefuck.enable = config.thefuck.enable;
  };
}
