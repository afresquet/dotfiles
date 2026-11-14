{ lib, config, ... }:
let
  cfg = config.bat;
in
{
  options = {
    bat.enable = lib.mkEnableOption "bat" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable { programs.bat.enable = true; };
}
