{
  flake.modules.nixos.fonts =
    { pkgs, ... }:
    {
      fonts = {
        fontconfig.enable = true;
        packages = with pkgs; [
          font-awesome
          nerd-fonts.hack
        ];
      };
    };
}
