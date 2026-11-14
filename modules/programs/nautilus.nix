{
  flake.modules.nixos.nautilus =
    {
      pkgs,
      ...
    }:
    {
      config = {
        environment.systemPackages = [ pkgs.nautilus ];
      };
    };
}
