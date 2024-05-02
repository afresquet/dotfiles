{ lib, config, ... }:
let
  cfg = config.yazi;
in
{
  options = {
    yazi.enable = lib.mkEnableOption "yazi" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable { programs.yazi.enable = true; };
}
