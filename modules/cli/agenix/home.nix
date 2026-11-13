{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.agenix;
in
{
  options = {
    agenix.enable = lib.mkEnableOption "agenix CLI for editing age-encrypted secrets" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable { home.packages = [ pkgs.agenix ]; };
}
