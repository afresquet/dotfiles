{
  flake.modules.nixos.heroic =
    {
      pkgs,
      ...
    }:
    {
      config = {
        environment.systemPackages = [ pkgs.heroic ];
      };
    };
}
