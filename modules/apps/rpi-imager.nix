{
  flake.modules.nixos.rpi-imager =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.rpi-imager ];
    };

  flake.modules.darwin.rpi-imager = _: {
    homebrew.casks = [ "raspberry-pi-imager" ];
  };
}
