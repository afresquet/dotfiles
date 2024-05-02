{ lib, config, ... }:
let
  cfg = config.eza;
in
{
  options = {
    eza.enable = lib.mkEnableOption "eza" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable { programs.eza.enable = true; };
}
