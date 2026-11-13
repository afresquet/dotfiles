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
  # Desktop MAC address for wake-desktop: raw single-line file.
  "desktop-mac.age".publicKeys = [
    keys.afresquet
    keys.homeServer
    keys.homeServerHost
  ];
  "explo-env.age".publicKeys = [
    keys.afresquet
    keys.homeServer
    keys.homeServerHost
  ];
  # Telegram bot for agent alerts and the Telegram-connected Claude session,
  # one bot per machine. TELEGRAM_BOT_TOKEN= and TELEGRAM_CHAT_ID= lines.
  "agent-telegram-home-server.age".publicKeys = [
    keys.afresquet
    keys.homeServer
    keys.homeServerHost
  ];
  # Fine-grained GitHub token for the issue agent: the dotfiles repo only,
  # read/write on contents, pull requests and issues. A GH_TOKEN= line.
  "github-agent.age".publicKeys = [
    keys.afresquet
    keys.homeServer
    keys.homeServerHost
  ];
  "agent-telegram-mac-mini.age".publicKeys = [
    keys.afresquet
    keys.alvarosMacMini
    keys.alvarosMacMiniHost
  ];
}
