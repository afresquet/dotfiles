{
  nixpkgs.overlays = [
    (import ./brave-wayland.nix)
    (import ./discord-wayland.nix)
    (import ./font-awesome-bump.nix)
    (import ./thefuck-nushell.nix)
    (import ./waybar-bump.nix)
  ];
}
