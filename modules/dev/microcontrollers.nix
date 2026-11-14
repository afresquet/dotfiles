{
  flake.modules.nixos.microcontrollers =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [ arduino-ide ];

      services.udev.packages = with pkgs; [
        platformio-core
        openocd
      ];
    };
}
