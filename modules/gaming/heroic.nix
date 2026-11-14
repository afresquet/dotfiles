{
  flake.modules.nixos.heroic =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.heroic ];
    };
}
