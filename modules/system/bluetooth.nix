{
  flake.modules.nixos.bluetooth =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.bluetooth;
    in
    {
      options = {
        bluetooth = {

          xboxController.enable = lib.mkEnableOption "xpadneo (Xbox controller driver)" // {
            default = true;
          };
        };
      };

      config = {
        hardware.bluetooth = {
          enable = true;
          powerOnBoot = true;
          settings.General = {
            JustWorksRepairing = "always";
            Experimental = true;
          };
        };

        hardware.xpadneo.enable = cfg.xboxController.enable;

        environment.systemPackages = [ pkgs.bluetuith ];
      };
    };
}
