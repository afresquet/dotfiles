{ lib, config, ... }:
let
  cfg = config.claude;
in
{
  options = {
    claude.enable = lib.mkEnableOption "Claude" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    programs.claude-code.enable = true;

    allowedUnfree = [ "claude-code" ];
  };
}
