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
    # Enable the OpenSSH daemon.
    services.openssh.enable = true;
  };
}
