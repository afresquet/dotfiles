{ lib, config, ... }:
let
  cfg = config.carapace;
in
{
  options = {
    carapace.enable = lib.mkEnableOption "Carapace" // {
      default = true;
    };
  };

  config = {
    programs.carapace = lib.mkIf cfg.enable { enable = true; };
  };
}
