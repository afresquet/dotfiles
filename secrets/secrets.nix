let
  keys = import ./keys.nix;

  allHostKeys = with keys; [
    alvaroDesktopHost
    alvaroLaptopHost
    alvarosMacMiniHost
    homeServerHost
  ];
in
{
  "tailscale-auth.age".publicKeys = [ keys.afresquet ] ++ allHostKeys;
  # HA long-lived access token: read on the Mac (where Prometheus runs).
  "home-assistant-llat.age".publicKeys = [
    keys.afresquet
    keys.alvarosMacMini
    keys.alvarosMacMiniHost
  ];
  # Grafana admin password: used by `export-grafana-dashboard` (Mac), where
  # Grafana itself runs. Raw single-line file, decrypted to
  # /run/agenix/grafana-password.
  "grafana-password.age".publicKeys = [
    keys.afresquet
    keys.alvarosMacMini
    keys.alvarosMacMiniHost
  ];
  "pihole-webpassword.age".publicKeys = [
    keys.afresquet
    keys.homeServer
    keys.homeServerHost
  ];
  "qbittorrent-webuipw.age".publicKeys = [
    keys.afresquet
    keys.homeServer
    keys.homeServerHost
  ];
  "mullvad-wg.age".publicKeys = [
    keys.afresquet
    keys.homeServer
    keys.homeServerHost
  ];
  "homepage-api-keys.age".publicKeys = [
    keys.afresquet
    keys.homeServer
    keys.homeServerHost
  ];
  "explo-env.age".publicKeys = [
    keys.afresquet
    keys.homeServer
    keys.homeServerHost
  ];
}
