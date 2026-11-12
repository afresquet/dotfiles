{
  config,
  lib,
  pkgs,
  inputs,
  outputs,
  ...
}:
let
  keys = import ../../secrets/keys.nix;
in
{
  imports = [
    inputs.nixos-raspberrypi.nixosModules.raspberry-pi-5.base
    inputs.nixos-raspberrypi.nixosModules.sd-image

    outputs.nixosModules.polyfills.default
    outputs.nixosModules.services.ssh
    outputs.nixosModules.services.avahi
    outputs.nixosModules.services.tailscale
    outputs.nixosModules.services.pihole
    outputs.nixosModules.services.home-assistant
    outputs.nixosModules.services.zigbee
    outputs.nixosModules.services.caddy
    outputs.nixosModules.services.bluetooth
    outputs.nixosModules.services.qbittorrent
    outputs.nixosModules.services.arr
    outputs.nixosModules.services.navidrome
    outputs.nixosModules.services.git-server
    outputs.nixosModules.services.agent-telegram
    outputs.nixosModules.services.slskd
    outputs.nixosModules.services.explo
    outputs.nixosModules.services.jellyfin
    outputs.nixosModules.services.vpn
    outputs.nixosModules.services.dashboard
    outputs.nixosModules.services.auto-upgrade
    outputs.nixosModules.services.monitoring

    ./settings.nix
  ];

  bluetooth.xboxController.enable = false;
  qbittorrent.enable = true;
  arrStack.enable = true;
  navidrome.enable = true;
  gitServer = {
    enable = true;
    # Heeler only needs terminal access, not repo admin.
    adminKeys =
      lib.remove keys.heeler
        config.users.users.${config.username}.openssh.authorizedKeys.keys;
  };
  agentTelegram = {
    enable = true;
    secretFile = ../../secrets/agent-telegram-home-server.age;
  };
  slskd.enable = true;
  explo.enable = true;
  jellyfin.enable = true;
  vpn.enable = true;
  dashboard.enable = true;
  monitoring = {
    enable = true;
    serverHost = "alvaros-mac-mini.${config.tailnet.domain}";
  };

  pihole.enable = true;
  home-assistant-container = {
    enable = true;
    hacs.enable = true;
    packages = {
      dune_weaver = ./home-assistant/dune-weaver.yaml;
      laundry_done = ./home-assistant/laundry-done.yaml;
      nyx_food = ./home-assistant/nyx-food.yaml;
    };
  };
  zigbee = {
    enable = true;
    device = "/dev/serial/by-id/usb-ITead_Sonoff_Zigbee_3.0_USB_Dongle_Plus_121080dc0ca1ef11824eaaa361ce3355-if00-port0";
  };
  reverseProxy.enable = true;
  # `extraUpFlags` is only applied when an unauthenticated node runs
  # `tailscale up`. Reconcile routes on every activation for an already
  # authenticated server as well.
  services.tailscale.extraSetFlags = [
    "--advertise-routes=192.168.0.37/32"
  ];

  _module.args.nixos-raspberrypi = inputs.nixos-raspberrypi;

  nixpkgs.overlays = [
    outputs.overlays.additions
    outputs.overlays.modifications
    (
      final: _:
      let
        cachedPkgs = inputs.nixpkgs.legacyPackages.${final.stdenv.hostPlatform.system};
      in
      {
        inherit (cachedPkgs)
          bazarr
          grafana-alloy
          jellyfin
          prowlarr
          qbittorrent-nox
          radarr
          readarr
          seerr
          sonarr
          ;
      }
    )
  ];

  networking.hostName = config.hostname;
  networking.networkmanager = {
    enable = true;
    # Hand DNS over to Pi-hole (so the Pi resolves *.ts.net via the dnsmasq
    # forwarder we add in pihole.nix). Without this, NetworkManager would
    # rewrite resolv.conf with the router's DNS on every link change.
    dns = "none";
  };
  networking.nameservers = [ "127.0.0.1" ];

  age.secrets.desktop-mac = {
    file = ../../secrets/desktop-mac.age;
    owner = config.username;
  };
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "wake-desktop" ''
      exec ${lib.getExe pkgs.wakeonlan} "$(<${config.age.secrets.desktop-mac.path})"
    '')
  ];

  time.timeZone = "Europe/Madrid";

  # Headless: nobody is around to reboot it for a kernel update.
  autoUpgrade.allowReboot = true;

  # Raspberry Pi kernels ship with the memory cgroup controller disabled by
  # default to save a few % of overhead. Without it, /sys/fs/cgroup/.../memory.*
  # files don't exist, so cAdvisor and systemd_exporter report 0 for all
  # container/unit memory metrics. Re-enabling requires a reboot.
  boot.kernelParams = [
    "cgroup_enable=memory"
    "cgroup_memory=1"
    # Experiment: silent full-system freezes (journal just stops) started
    # with the 6.18.59 kernel, three in three days. Pi 5 + NVMe reports with
    # the same symptom point at NVMe/PCIe power saving
    # (home-assistant/operating-system#5098), so keep the drive and link
    # out of low-power states. The assertion below fires on a kernel bump.
    "nvme_core.default_ps_max_latency_us=0"
    "pcie_aspm=off"
  ];
  assertions = [
    {
      assertion = config.boot.kernelPackages.kernel.modDirVersion == "6.18.59";
      message = "Home-Server kernel is now ${config.boot.kernelPackages.kernel.modDirVersion}: the NVMe/PCIe power-saving workaround in hosts/home-server/configuration.nix was for silent freezes on 6.18.59. Check raspberrypi/linux for a fix, then drop `nvme_core.default_ps_max_latency_us=0` and `pcie_aspm=off` (watch for unclean shutdowns afterwards) along with this assertion.";
    }
  ];

  # Turn partial hangs into a reboot as well: the kernel panics on a soft
  # lockup or a task stuck in D state (e.g. blocked on storage) for 120s,
  # and reboots 10s after any panic instead of sitting there forever. The
  # hardware watchdog below covers hard lockups.
  boot.kernel.sysctl = {
    "kernel.softlockup_panic" = 1;
    "kernel.hung_task_panic" = 1;
    "kernel.panic" = 10;
  };
  boot.zfs.forceImportRoot = false;

  # Disable the system-wide NSS cache daemon (nsncd). It runs in the host's
  # network namespace and resolves all NSS lookups via the host's resolv.conf,
  # which means services inside the VPN namespace (Prowlarr, FlareSolverr) end
  # up using the ISP's DNS (Livebox) and inheriting its torrent-site DNS
  # poisoning. Without nscd, each process does its own NSS lookups in its own
  # network namespace.
  services.nscd.enable = false;
  system.nssModules = lib.mkForce [ ];
  # Several *arr systemd units have BindReadOnlyPaths=/run/nscd baked into
  # their hardening config (upstream assumes nscd is always running). Create
  # an empty target so the mount-namespace setup succeeds.
  systemd.tmpfiles.rules = [ "d /run/nscd 0755 root root -" ];

  fileSystems."/mnt/hdd" = {
    device = "/dev/disk/by-label/hdd";
    fsType = "ext4";
    options = [
      "noatime"
      "nofail"
    ];
  };

  # zram first: compressed RAM-backed swap absorbs memory-pressure spikes
  # without touching disk. With 8 GiB RAM and zstd, 50% gives ~4 GiB of zram
  # which typically holds ~10-12 GiB of cold pages.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  # Disk swapfile on the NVMe as a backstop for whatever zram can't hold.
  # Lower priority than zram (NixOS gives zram priority 5 by default), so the
  # kernel only spills here once zram is full.
  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 4096; # MiB
    }
  ];

  # smartd sends SMART ENABLE to every drive it monitors at startup. The
  # USB hard drive shipped with SMART disabled, which left smartctl_exporter
  # failing with exit status 4 and no health metrics for it. Listed by id
  # rather than autodetected because the USB drive needs `-d sat` to be
  # reached through its bridge.
  services.smartd = {
    enable = true;
    autodetect = false;
    devices = [
      {
        device = "/dev/disk/by-id/ata-TOSHIBA_MQ04UBB400_Z1BAT1QNT";
        options = "-d sat";
      }
      { device = "/dev/disk/by-id/nvme-CT500P310SSD8_25475480C930"; }
    ];
  };

  # Arm the hardware watchdog: a hard freeze (kernel lockup, no log) then
  # reboots on its own instead of waiting for someone to pull the plug.
  # 15s is the BCM2835 watchdog's maximum.
  systemd.settings.Manager.RuntimeWatchdogSec = "15s";

  users.users.${config.username} = {
    isNormalUser = true;
    initialPassword = "pi";
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
    inherit (config) description;
    # Login shell is bash so ssh-driven tooling (e.g. Ghostty's ssh-terminfo
    # wrapper, which sends bash syntax to the remote) parses correctly.
    # Interactive sessions hand off to nushell via bash's initExtra.
    shell = pkgs.bash;
    openssh.authorizedKeys.keys = with keys; [
      afresquet
      alvaroDesktop
      alvaroLaptop
      alvarosMacMini
      alvaroPhone
      heeler
    ];
  };

  nix.settings = {
    auto-optimise-store = true;
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://nixos-raspberrypi.cachix.org"
      # This flake's own closures, pushed by the flake-update workflow so
      # the weekly auto-upgrade downloads instead of compiling.
      "https://afresquet-dotfiles.cachix.org"
    ];
    trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
      "afresquet-dotfiles.cachix.org-1:14Rw96q4DN7l6kkvY3ducxkBwDQrQv8BlHg4XIxkC50="
      # Packages built and signed on the Mac mini (its `secret-key-files`).
      "alvaros-mac-mini-1:giqVho0+L/l5+xMGZSyys7ntJxXAD+ga/zH/kELChBY="
    ];
  };

  system.stateVersion = "25.05";
}
