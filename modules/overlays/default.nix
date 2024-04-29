{
  nixpkgs.overlays = [
    (import ./brave-wayland.nix)
    (import ./discord-wayland.nix)
    (import ./thefuck-nushell.nix)
  ];
}
