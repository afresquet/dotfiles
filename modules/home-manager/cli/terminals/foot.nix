{ lib, config, ... }:
let
  cfg = config.foot;
in
{
  options = {
    foot.enable = lib.mkEnableOption "foot" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable { programs.foot.enable = true; };
}
