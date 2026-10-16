{ lib, config, ... }:
let
  cfg = config.herdr;
in
{
  options.herdr.enable = lib.mkEnableOption "Herdr" // {
    default = true;
  };

  config = lib.mkIf cfg.enable {
    programs.herdr.enable = true;
  };
}
