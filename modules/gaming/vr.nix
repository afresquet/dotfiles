{
  flake.modules.nixos.vr =
    {
      pkgs,
      ...
    }:
    {
      config = {
        services.wivrn = {
          enable = true;
          openFirewall = true;
          autoStart = true;
        };

        environment.systemPackages = [ pkgs.bs-manager ];
      };
    };
}
