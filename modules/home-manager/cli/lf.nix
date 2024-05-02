{ lib, config, ... }:
let
  cfg = config.lf;
in
{
  options = {
    lf.enable = lib.mkEnableOption "lf" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable { programs.lf.enable = true; };
}
