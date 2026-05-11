# Public SSH keys — not secret, but kept next to `secrets.nix`.
#
# Two classes of keys:
# - User keys (per-device personal ed25519 pubkeys) — go into
#   `users.users.<>.openssh.authorizedKeys.keys` so each machine can SSH into
#   the others. Also let you edit secrets via `agenix -e` from your user shell.
# - Host keys (each box's `/etc/ssh/ssh_host_ed25519_key.pub`) — go into the
#   agenix recipient list so the system can decrypt at activation.
{
  # User keys
  afresquet = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICYZ8TDYb7iqWylxbjX0xTc+Ob9m5q9xtQxT+x2jtj+t afresquet";

  alvaroDesktop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDHTRDzddRLTvDOW2xY2mRunvH0ues6UOKYhUAP3WY4l afresquet@nixos";
  alvaroLaptop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKsMkcVXZB5KeX7DbBVLx7rvV3M58ra+JErljehSloJF afresquet@alvaro-laptop";
  alvarosMacMini = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILPHoc0Z8Rikc7w9UDCGQRBvZND9g5VnQKb18X2GAJQW afresquet@mac-mini";
  homeServer = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC7Uq8d/AuGxFNLdN1Ukyw62JaqVIK8b1bWUcJV0hbIJ afresquet@home-server";

  # Host keys — contents of /etc/ssh/ssh_host_ed25519_key.pub on each box.
  alvaroDesktopHost = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDN3fAAWJ0exzIxDA/Gwu9erAqXMbsCfG7CUEmytEyIL root@nixos";
  alvaroLaptopHost = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJVARisSHq5IBG8KSsvc/Y/mK5zqeDx6T8U42UeucTa/ root@nixos";
  alvarosMacMiniHost = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKmN5zXL7GZE3xyEb8x7HZbkgIPwfYU9XJJbCNzalU5l";
  homeServerHost = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIuuks01ZK/bEG97kAtPtnNqqgoSkl3vE177nSr3NX2U root@Home-Server";
}
