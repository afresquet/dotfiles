{ lib, config, ... }:
let
  cfg = config.silicon;
in
{
  # programs.silicon, until home-manager has it.
  imports = [ ./polyfill.nix ];

  options = {
    silicon.enable = lib.mkEnableOption "silicon" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    programs.silicon = {
      enable = true;

      settings = ''
        --no-window-controls
        --to-clipboard
      '';
    };
  };
}
