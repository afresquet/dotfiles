{ ... }: {
  imports = [
    ./audio.nix
    ./bluetooth.nix
    ./mounting.nix
    ./mullvad.nix
    ./networking.nix
    ./printing.nix
    ./ssh.nix
  ];
}
