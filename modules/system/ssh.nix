{ self, ... }:
let
  userOf = c: c.config.system.primaryUser;
in
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
          User = userOf self.nixosConfigurations.Home-Server;
        };
        "mac mac-mini" = {
          HostName = "alvaros-mac-mini";
          User = userOf self.darwinConfigurations.Alvaros-Mac-mini;
        };
        desktop = {
          HostName = "alvaro-desktop";
          User = userOf self.nixosConfigurations.Alvaro-Desktop;
        };
        laptop = {
          HostName = "alvaro-laptop";
          User = userOf self.nixosConfigurations.Alvaro-Laptop;
        };
      };
    };
  };
}
