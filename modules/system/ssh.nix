{
  flake.modules.nixos.ssh = _: {
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

  flake.modules.homeManager.ssh = _: {
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
