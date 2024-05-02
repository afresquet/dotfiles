{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.dropbox;
in
{
  options = {
    dropbox.enable = lib.mkEnableOption "Dropbox" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable { environment.systemPackages = [ pkgs.maestral ]; };
}
