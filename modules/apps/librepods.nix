# AirPods battery, noise control and ear detection over Apple's reverse-engineered
# AAP protocol. Bluez's `DeviceID = bluetooth:004C:0000:0000` (posing as an
# Apple device) is left out: upstream only needs it for the hearing-aid
# features and warns it makes the AirPods drop the connection.
{ self, ... }:
{
  flake.modules.nixos.librepods =
    { config, ... }:
    {
      imports = with self.modules.nixos; [
        primary-user
        bluetooth
      ];

      # Installs librepods behind a cap_net_admin wrapper the group may run.
      programs.librepods.enable = true;

      # Upstream's README also suggests WirePlumber's
      # `bluez5.dummy-avrcp-player = true` for tap gestures. Don't: with a
      # player registered, bluez hands the AirPods' play/pause to it instead
      # of emitting media keys, and the taps do nothing.
      users.users.${config.system.primaryUser}.extraGroups = [ "librepods" ];
    };

  flake.modules.homeManager.librepods =
    { lib, pkgs, ... }:
    {
      systemd.user.services.librepods = {
        Unit = {
          Description = "LibrePods AirPods tray";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Service = {
          # Qt picks its tray backend at startup and falls back to XEmbed, which
          # Wayland lacks, when no StatusNotifier watcher is up yet; Waybar
          # starts from Hyprland's start hook and may not have registered its
          # tray.
          ExecStartPre = "${lib.getExe' pkgs.bash "bash"} -c 'until ${lib.getExe' pkgs.systemd "busctl"} --user status org.kde.StatusNotifierWatcher >/dev/null 2>&1; do sleep 1; done'";
          # The capability wrapper from programs.librepods, not the store binary.
          ExecStart = "/run/wrappers/bin/librepods --hide";
          Restart = "on-failure";
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };

      # Connected/disconnected popups aren't worth keeping in the control
      # center. Qt sends them under the executable's name and the desktop
      # file name, so match either.
      services.swaync.settings.notification-visibility = {
        librepods-app = {
          state = "transient";
          app-name = "librepods";
        };
        librepods-desktop = {
          state = "transient";
          desktop-entry = "librepods";
        };
      };
    };
}
