{ lib, config, ... }: {
  options = {
    eza.enable = lib.mkEnableOption "eza";
  };

  config = {
    programs.eza.enable = config.eza.enable;
  };
}
