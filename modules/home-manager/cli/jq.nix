{ lib, config, ... }:
let
  cfg = config.jq;
in
{
  options = {
    jq.enable = lib.mkEnableOption "jq" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable { programs.jq.enable = true; };
}
