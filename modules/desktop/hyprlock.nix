{
  flake.modules.homeManager.hyprlock =
    { lib, config, ... }:
    let
      cfg = config.hyprlock;
    in
    {
      options = {
        hyprlock = {
          # Requires fprintd on the system and `security.pam.services.hyprlock`
          # without fprintAuth, so password and fingerprint run in parallel.
          fingerprint = lib.mkEnableOption "fingerprint unlock";
        };
      };

      config = {
        programs.hyprlock = {
          enable = true;
          settings = {
            general.hide_cursor = true;
            auth.fingerprint = lib.mkIf cfg.fingerprint {
              enabled = true;
              ready_message = "Scan fingerprint to unlock";
              present_message = "Scanning...";
            };
          };
        };

        services.hypridle = {
          enable = true;
          settings = {
            general = {
              lock_cmd = "pidof hyprlock || hyprlock";
              # Lock before suspend (lid close, wlogout) and wait until the lock
              # screen is up so the desktop never flashes on resume.
              before_sleep_cmd = "loginctl lock-session";
              inhibit_sleep = 3;
            };
          };
        };
      };
    };
}
