{
  flake.modules.nixos.mullvad =
    {
      pkgs,
      ...
    }:
    {
      config = {
        environment.systemPackages = [ pkgs.mullvad-vpn ];

        services.mullvad-vpn.enable = true;
      };
    };
}
