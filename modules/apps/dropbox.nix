{
  flake.modules.nixos.dropbox =
    {
      pkgs,
      ...
    }:
    {
      config = {
        environment.systemPackages = with pkgs; [
          maestral
          maestral-gui
        ];
      };
    };
}
