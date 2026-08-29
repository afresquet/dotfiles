{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.quickemu;
in
{
  options = {
    quickemu.enable = lib.mkEnableOption "Quickemu" // {
      default = false;
    };

    # Off by default: it takes a USB controller away from the host entirely, so it
    # is only worth enabling while a guest actually needs real USB hardware.
    quickemu.usbPassthrough = lib.mkEnableOption "handing the Matisse USB controller to VMs via VFIO" // {
      default = false;
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      # Bundles qemu, swtpm (Windows 11 TPM) and spice-gtk (`spicy`, the viewer
      # that does USB redirection without needing root or udev rules).
      # spice-gtk is exposed separately so `spicy` can reattach to a VM that is
      # already running, e.g. `spicy -h 127.0.0.1 -p <spice_port>`.
      # qemu and swtpm are also exposed directly so a VM can be driven by hand
      # without quickemu: quickemu keeps its copies private, so `qemu-system-x86_64`
      # and the OVMF firmware under share/qemu are otherwise not on PATH.
      environment.systemPackages = with pkgs; [
        quickemu
        spice-gtk
        qemu
        swtpm
      ];
    }

    (lib.mkIf cfg.usbPassthrough {
      # SPICE USB redirection needs `spice-client-glib-usb-acl-helper` to be setuid,
      # otherwise spicy fails with "Error setting facl: Operation not permitted" —
      # /dev/bus/usb nodes are root:root 0664 and passthrough needs write access.
      virtualisation.spiceUSBRedirection.enable = true;

      # Dedicate the Matisse USB controller (0e:00.3, alone in IOMMU group 21) to
      # VMs via VFIO. Emulated USB cannot carry the Xbox GIP protocol — the pad
      # enumerates in Windows but never completes its handshake, so no input device
      # is created — and passing real hardware through is the only thing that works.
      #
      # This removes the controller from Linux entirely: only its own ports (usb3,
      # usb4) are affected. Keyboard, mouse, Bluetooth and AURA are on the chipset
      # controller at 01:00.0 and are untouched. Exactly one device matches this ID.
      boot.initrd.kernelModules = [
        "vfio_pci"
        "vfio_iommu_type1"
        "vfio"
      ];
      boot.extraModprobeConfig = ''
        options vfio-pci ids=1022:149c
      '';

      # Let the desktop user open /dev/vfio/* without root.
      # The 045e rule is a fallback for `-device usb-host` on the emulated buses.
      services.udev.extraRules = ''
        SUBSYSTEM=="usb", ATTR{idVendor}=="045e", TAG+="uaccess"
        SUBSYSTEM=="vfio", OWNER="${config.username}"
      '';

      # VFIO pins the guest's entire RAM, so the default 8MB memlock ceiling is far
      # too low and qemu fails to start with "Cannot allocate memory".
      security.pam.loginLimits = [
        {
          domain = config.username;
          type = "hard";
          item = "memlock";
          value = "unlimited";
        }
        {
          domain = config.username;
          type = "soft";
          item = "memlock";
          value = "unlimited";
        }
      ];
    })
  ]);
}
