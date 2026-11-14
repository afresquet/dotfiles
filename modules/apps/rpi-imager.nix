{
  flake.modules.nixos.rpi-imager =
    {
      pkgs,
      ...
    }:
    {
      config = {
        environment.systemPackages = [ pkgs.rpi-imager ];
      };
    };

  flake.modules.darwin.rpi-imager = _: {
    config = {
      homebrew.casks = [ "raspberry-pi-imager" ];
    };
  };
}
