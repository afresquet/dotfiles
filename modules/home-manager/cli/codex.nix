{
  lib,
  config,
  ...
}:
let
  cfg = config.codex;
in
{
  options.codex.enable = lib.mkEnableOption "Codex" // {
    default = true;
  };

  config = lib.mkIf cfg.enable {
    programs.codex.enable = true;
  };
}
