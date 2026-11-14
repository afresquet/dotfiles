{
  flake.modules.nixos.calibre =
    {
      pkgs,
      ...
    }:
    {
      config = {
        environment.systemPackages = [ pkgs.calibre ];
      };
    };
}
