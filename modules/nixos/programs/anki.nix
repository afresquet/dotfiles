{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.anki;
in
{
  options = {
    anki.enable = lib.mkEnableOption "Anki" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      anki
    ];
  };
}
