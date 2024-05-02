{ lib, config, ... }: {
  options = {
    fastfetch.enable = lib.mkEnableOption "Fastfetch";
  };

  config = {
    programs.fastfetch.enable = config.fastfetch.enable;
  };
}
