{ self, ... }:
{
  flake.modules.nixos.openlogi =
    {
      config,
      pkgs,
      ...
    }:
    {
      imports = [ self.modules.nixos.primary-user ];

      config = {
        environment.systemPackages = [ pkgs.openlogi ];

        # NixOS writes extraRules after systemd's uaccess ACL handler, so a late
        # TAG+="uaccess" does not grant an ACL. Assign only the matching Logitech
        # device nodes directly to the configured desktop user instead.
        services.udev.extraRules = ''
          KERNEL=="hidraw*", ATTRS{idVendor}=="046d", OWNER="${config.system.primaryUser}", MODE="0600"
          KERNEL=="hidraw*", KERNELS=="0005:046D:*", OWNER="${config.system.primaryUser}", MODE="0600"
          SUBSYSTEM=="input", KERNEL=="event*", ATTRS{idVendor}=="046d", OWNER="${config.system.primaryUser}", MODE="0600"
          SUBSYSTEM=="input", KERNEL=="event*", KERNELS=="0005:046D:*", OWNER="${config.system.primaryUser}", MODE="0600"
          KERNEL=="uinput", OWNER="${config.system.primaryUser}", MODE="0600", OPTIONS+="static_node=uinput"
        '';
      };
    };
}
