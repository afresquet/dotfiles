{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.openlogi;
in
{
  options.openlogi.enable = lib.mkEnableOption "OpenLogi";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.openlogi ];

    # NixOS writes extraRules after systemd's uaccess ACL handler, so a late
    # TAG+="uaccess" does not grant an ACL. Assign only the matching Logitech
    # device nodes directly to the configured desktop user instead.
    services.udev.extraRules = ''
      KERNEL=="hidraw*", ATTRS{idVendor}=="046d", OWNER="${config.username}", MODE="0600"
      KERNEL=="hidraw*", KERNELS=="0005:046D:*", OWNER="${config.username}", MODE="0600"
      SUBSYSTEM=="input", KERNEL=="event*", ATTRS{idVendor}=="046d", OWNER="${config.username}", MODE="0600"
      SUBSYSTEM=="input", KERNEL=="event*", KERNELS=="0005:046D:*", OWNER="${config.username}", MODE="0600"
      KERNEL=="uinput", OWNER="${config.username}", MODE="0600", OPTIONS+="static_node=uinput"
    '';
  };
}
