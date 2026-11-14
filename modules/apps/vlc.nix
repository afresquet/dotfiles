{
  flake.modules.nixos.vlc =
    {
      pkgs,
      ...
    }:
    {
      config = {
        environment.systemPackages = [ pkgs.vlc ];
      };
    };
}
