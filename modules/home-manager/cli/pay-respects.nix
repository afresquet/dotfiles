{ lib, config, ... }:
let
  cfg = config.pay-respects;
in
{
  options = {
    pay-respects.enable = lib.mkEnableOption "pay-respects" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable { programs.pay-respects.enable = true; };
}
