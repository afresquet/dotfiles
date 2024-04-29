{ lib, config, ... }: {
  options = {
    btop.enable = lib.mkEnableOption "btop";
  };

  config = {
    programs.btop.enable = config.btop.enable;
  };
}
