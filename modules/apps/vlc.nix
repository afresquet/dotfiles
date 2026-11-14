{
  flake.modules.nixos.vlc =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.vlc ];
    };
}
