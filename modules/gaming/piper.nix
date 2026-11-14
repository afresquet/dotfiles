{
  flake.modules.nixos.piper =
    { pkgs, ... }:
    {
      services.ratbagd.enable = true;

      environment.systemPackages = [ pkgs.piper ];
    };
}
