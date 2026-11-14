{
  flake.modules.nixos.minecraft =
    {
      pkgs,
      ...
    }:
    {
      config = {
        environment.systemPackages = [ pkgs.prismlauncher ];
      };
    };
}
