{
  nixpkgs.overlays = [
    (import ./font-awesome-bump.nix)
  ];
}
