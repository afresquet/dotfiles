{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config._1password;
in
{
  options = {
    _1password.enable = lib.mkEnableOption "1Password" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs._1password-gui ];

    allowedUnfree = [
      "1password"
      "1password-gui"
    ];
  };
}
