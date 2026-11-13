{ lib, config, ... }:
let
  cfg = config.fzf;
in
{
  options = {
    fzf.enable = lib.mkEnableOption "fzf" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable { programs.fzf.enable = true; };
}
