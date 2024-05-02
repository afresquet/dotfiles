{ lib, config, ... }:
let
  cfg = config.zellij;
in
{
  options = {
    zellij.enable = lib.mkEnableOption "Zellij" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable { programs.zellij.enable = true; };
}
