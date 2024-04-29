{ lib, config, ... }: {
  options = {
    jq.enable = lib.mkEnableOption "jq";
  };

  config = {
    programs.jq.enable = config.jq.enable;
  };
}
