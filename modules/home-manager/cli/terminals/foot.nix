{ lib, config, isLinux, ... }:
let
  cfg = config.foot;
in
{
  options = {
    foot.enable = lib.mkEnableOption "foot" // {
      default = isLinux;
    };
  };

  config = lib.mkIf cfg.enable { programs.foot.enable = true; };
}
