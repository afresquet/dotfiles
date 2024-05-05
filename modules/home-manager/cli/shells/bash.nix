{ lib, config, ... }:
let
  cfg = config.bash;
in
{
  options = {
    bash.enable = lib.mkEnableOption "bash" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable { programs.bash.enable = true; };
}
