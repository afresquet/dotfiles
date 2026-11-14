{ lib, config, ... }:
let
  cfg = config.direnv;
in
{
  options = {
    direnv.enable = lib.mkEnableOption "Direnv" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };
}
