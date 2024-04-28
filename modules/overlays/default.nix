{
  nixpkgs.overlays = [
    (import ./font-awesome-bump.nix)
    (import ./thefuck-nushell.nix)
    (import ./waybar-bump.nix)
  ];
}
