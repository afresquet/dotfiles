{ config, lib, ... }:
let
  cfg = config.openssh;
in
{
  options = {
    openssh.enable = lib.mkEnableOption "Apple's built-in OpenSSH server (Remote Login)" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    services.openssh.enable = true;
  };
}
