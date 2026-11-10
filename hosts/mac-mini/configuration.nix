{
  config,
  outputs,
  ...
}:
let
  keys = import ../../secrets/keys.nix;
in
{
  imports = [
    outputs.darwinModules.programs.default
    outputs.darwinModules.services.default

    ./settings.nix
  ];

  users.users.${config.system.primaryUser}.openssh.authorizedKeys.keys = with keys; [
    afresquet
    alvaroDesktop
    alvaroLaptop
    alvaroPhone
    alvaroPhoneShortcuts
    heeler
  ];

  system.primaryUser = config.username;
  networking.hostName = config.hostname;

  monitoring.enable = true;
  agentTelegram = {
    enable = true;
    secretFile = ../../secrets/agent-telegram-mac-mini.age;
  };

  # Server-mode: this Mini is headless, runs Prometheus/Grafana 24/7, and
  # should come back from anything (sleep, freeze, power loss) without the
  # user touching it.
  power = {
    restartAfterPowerFailure = true;
    restartAfterFreeze = true;
    sleep = {
      computer = "never";
      display = 30; # display can still sleep
      harddisk = "never";
    };
  };

  # Auto-login. nix-darwin sets the loginwindow preference; macOS also reads
  # /etc/kcpassword which holds an obfuscated copy of the password. The
  # kcpassword file gets created the first time you toggle "Automatic login"
  # in System Settings → Users & Groups (it needs to know the password). After
  # that the nix-darwin setting keeps the username pinned across rebuilds.
  system.defaults.loginwindow.autoLoginUser = config.system.primaryUser;

  homebrew.enable = true;

  # nix-darwin's power module covers sleep + auto-restart but not these two.
  # `pmset -a` writes to NVRAM so it sticks across reboots.
  #   womp 1     wake on magic packet (so anything on the LAN can WoL it)
  #   powernap 0 disable powernap to avoid weird half-awake states that
  #              break Tailscale connectivity
  system.activationScripts.postActivation.text = ''
    pmset -a womp 1 powernap 0
  '';

  # Bring in the dotfiles `pkgs/` overlay (custom packages like
  # export-grafana-dashboard). `additions` injects everything from pkgs/;
  # `modifications` is the patched-pkgs overlay both hosts share.
  nixpkgs.overlays = [
    outputs.overlays.additions
    outputs.overlays.modifications
  ];

  # Determinate manages the Nix installation; let it own nix.conf.
  nix.enable = false;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 5;

  # The platform the configuration will be used on.
  nixpkgs.hostPlatform = "aarch64-darwin";
}
