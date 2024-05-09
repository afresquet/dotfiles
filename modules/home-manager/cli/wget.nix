{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.wget;
in
{
  options = {
    wget.enable = lib.mkEnableOption "wget" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable { home.packages = [ pkgs.wget ]; };
}
