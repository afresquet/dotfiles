{
  lib,
  config,
  outputs,
  ...
}:
let
  cfg = config.silicon;
in
{
  options = {
    silicon.enable = lib.mkEnableOption "silicon" // {
      default = true;
    };
  };

  imports = [ outputs.homeManagerModules.polyfills.silicon ];

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
