{ lib, config, ... }:
let
  cfg = config.skim;
in
{
  options = {
    skim.enable = lib.mkEnableOption "skim" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable { programs.skim.enable = true; };
}
