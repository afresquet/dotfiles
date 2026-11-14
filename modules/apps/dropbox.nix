{
  flake.modules.nixos.dropbox =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        maestral
        maestral-gui
      ];
    };
}
