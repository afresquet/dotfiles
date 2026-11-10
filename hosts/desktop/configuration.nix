{ config, ... }:
let
  keys = import ../../secrets/keys.nix;
in
{
  imports = [
    ../configuration.nix

    ./settings.nix

    ./hardware-configuration.nix
  ];

  boot.initrd.kernelModules = [ "amdgpu" ];
  services.xserver.videoDrivers = [ "amdgpu" ];

  sunshine.enable = true;

  networking.interfaces.enp9s0.wakeOnLan.enable = true;

  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (
        subject.user == "${config.username}" &&
        (action.id == "org.freedesktop.login1.suspend" ||
          action.id == "org.freedesktop.login1.suspend-multiple-sessions")
      ) {
        return polkit.Result.YES;
      }
    });
  '';

  quickemu.enable = true;
  openlogi.enable = true;

  users.users.${config.username}.openssh.authorizedKeys.keys = with keys; [
    afresquet
    alvaroLaptop
    alvarosMacMini
    alvaroPhone
    alvaroPhoneShortcuts
    heeler
  ];
}
