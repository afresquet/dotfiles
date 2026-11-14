{ lib, config, ... }:
let
  cfg = config.starship;
in
{
  options = {
    starship.enable = lib.mkEnableOption "Starship" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    programs.starship = {
      enable = true;

      settings = {
        add_newline = true;
      };
    };
  };
}
