{
  flake.modules.nixos.calibre =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.calibre ];
    };
}
