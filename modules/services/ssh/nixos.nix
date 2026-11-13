{ lib, config, ... }:
let
  cfg = config.ssh;
in
{
  options = {
    ssh.enable = lib.mkEnableOption "SSH" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    services.openssh = {
      enable = true;
      # Keys only: keyboard-interactive would otherwise still offer a PAM
      # password prompt with PasswordAuthentication off.
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
      };
    };
  };
}
