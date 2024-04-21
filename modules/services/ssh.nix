{ lib, config, ... }: {
  options = {
    ssh.enable = lib.mkEnableOption "SSH";
  };

  config = {
    ssh.enable = lib.mkDefault true;

    # Enable the OpenSSH daemon.
    services.openssh.enable = config.ssh.enable;
  };
}
