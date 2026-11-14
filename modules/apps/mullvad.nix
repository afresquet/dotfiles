{
  flake.modules.nixos.mullvad =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.mullvad-vpn ];

      services.mullvad-vpn.enable = true;
    };
}
