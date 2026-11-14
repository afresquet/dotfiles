{
  flake.modules.nixos.lutris =
    {
      pkgs,
      ...
    }:
    {
      config = {
        environment.systemPackages = [ pkgs.lutris ];
      };
    };
}
