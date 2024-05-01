{ lib, config, ... }: {
  options = {
    bat.enable = lib.mkEnableOption "bat";
  };

  config = {
    programs.bat.enable = config.bat.enable;
  };
}
