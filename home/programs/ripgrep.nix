{ lib, config, ... }: {
  options = {
    ripgrep.enable = lib.mkEnableOption "ripgrep";
  };

  config = {
    programs.ripgrep.enable = config.ripgrep.enable;
  };
}
