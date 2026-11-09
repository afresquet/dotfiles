{
  lib,
  config,
  ...
}:
let
  cfg = config.brave;
in
{
  options = {
    brave.enable = lib.mkEnableOption "Brave Browser (Homebrew cask)" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable { homebrew.casks = [ "brave-browser" ]; };
}
