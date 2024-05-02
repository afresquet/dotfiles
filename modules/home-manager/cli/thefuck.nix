{ lib, config, ... }:
let
  cfg = config.thefuck;
in
{
  options = {
    thefuck.enable = lib.mkEnableOption "thefuck" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable { programs.thefuck.enable = true; };
}
