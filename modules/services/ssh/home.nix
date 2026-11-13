{ lib, config, ... }:
let
  cfg = config.ssh;
in
{
  options.ssh.enable = lib.mkEnableOption "SSH" // {
    default = true;
  };

  config = lib.mkIf cfg.enable {
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;

      settings = {
        "pi home-server" = {
          HostName = "home-server";
          User = "pi";
        };
        "mac mac-mini" = {
          HostName = "alvaros-mac-mini";
          User = "afresquet";
        };
        desktop = {
          HostName = "alvaro-desktop";
          User = "afresquet";
        };
        laptop = {
          HostName = "alvaro-laptop";
          User = "afresquet";
        };
      };
    };
  };
}
