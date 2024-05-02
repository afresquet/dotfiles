{ lib, config, ... }:
let
  cfg = config.ripgrep;
in
{
  options = {
    ripgrep.enable = lib.mkEnableOption "ripgrep" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable { programs.ripgrep.enable = true; };
}
