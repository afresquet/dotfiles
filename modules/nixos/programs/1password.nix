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
    programs._1password.enable = true;
    programs._1password-gui = {
      enable = true;
      polkitPolicyOwners = [ config.username ];
    };

    allowedUnfree = [
      "1password"
      "1password-cli"
      "1password-gui"
    ];
  };
}
