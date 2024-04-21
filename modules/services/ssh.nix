{ lib, config, ... }: {
  options = {
    ssh.enable = lib.mkEnableOption "SSH";
  };

  config = {
    # Enable the OpenSSH daemon.
    services.openssh.enable = config.ssh.enable;
  };
}
