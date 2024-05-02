{
  lib,
  config,
  outputs,
  ...
}:
let
  cfg = config.fastfetch;
in
{
  options = {
    fastfetch.enable = lib.mkEnableOption "Fastfetch" // {
      default = true;
    };
  };

  imports = [ outputs.homeManagerModules.polyfills.fastfetch ];

  config = lib.mkIf cfg.enable { programs.fastfetch.enable = true; };
}
