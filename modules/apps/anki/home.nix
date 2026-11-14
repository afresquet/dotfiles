{
  lib,
  config,
  isLinux,
  ...
}:
let
  cfg = config.anki;
in
{
  options.anki.enable = lib.mkEnableOption "Anki" // {
    default = isLinux;
  };

  config = lib.mkIf cfg.enable { programs.anki.enable = true; };
}
