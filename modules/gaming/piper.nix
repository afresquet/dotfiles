{
  flake.modules.nixos.piper =
    {
      pkgs,
      ...
    }:
    {
      config = {
        services.ratbagd.enable = true;

        environment.systemPackages = [ pkgs.piper ];
      };
    };
}
