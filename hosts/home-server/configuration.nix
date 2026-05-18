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
    inputs.nixos-raspberrypi.nixosModules.raspberry-pi-5.page-size-16k
    inputs.nixos-raspberrypi.nixosModules.sd-image

    outputs.nixosModules.polyfills.default
    outputs.nixosModules.services.ssh
    outputs.nixosModules.services.avahi
    outputs.nixosModules.services.tailscale
    outputs.nixosModules.services.pihole
    outputs.nixosModules.services.home-assistant
    outputs.nixosModules.services.caddy
    outputs.nixosModules.services.bluetooth
    outputs.nixosModules.services.qbittorrent
    outputs.nixosModules.services.arr
    outputs.nixosModules.services.musicseerr
    outputs.nixosModules.services.navidrome
    outputs.nixosModules.services.slskd
    outputs.nixosModules.services.explo
    outputs.nixosModules.services.jellyfin
    outputs.nixosModules.services.vpn
    outputs.nixosModules.services.dashboard
    outputs.nixosModules.services.monitoring

    ./settings.nix
  ];

  bluetooth.xboxController.enable = false;
  qbittorrent.enable = true;
  arrStack.enable = true;
  musicseerr.enable = true;
  navidrome.enable = true;
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
  };
  reverseProxy.enable = true;

  _module.args.nixos-raspberrypi = inputs.nixos-raspberrypi;

  nixpkgs.overlays = [
    outputs.overlays.additions
    outputs.overlays.modifications
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

  time.timeZone = "Europe/Madrid";

  # Raspberry Pi kernels ship with the memory cgroup controller disabled by
  # default to save a few % of overhead. Without it, /sys/fs/cgroup/.../memory.*
  # files don't exist, so cAdvisor and systemd_exporter report 0 for all
  # container/unit memory metrics. Re-enabling requires a reboot.
  boot.kernelParams = [
    "cgroup_enable=memory"
    "cgroup_memory=1"
  ];

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

  services.openssh.settings.PasswordAuthentication = false;

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
    ];
    trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
  };

  system.stateVersion = "25.05";
}
