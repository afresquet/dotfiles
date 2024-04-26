{
  nixpkgs.overlays = [
    (import ./font-awesome-bump.nix)
    (import ./waybar-bump.nix)
  ];
}
