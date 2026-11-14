{
  flake.modules.nixos.minecraft =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.prismlauncher ];
    };
}
