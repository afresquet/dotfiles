{ ... }: {
  imports = [
    ./audio.nix
    ./bluetooth.nix
    ./mullvad.nix
    ./networking.nix
    ./printing.nix
    ./ssh.nix
  ];
}
