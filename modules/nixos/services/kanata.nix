{ lib, config, ... }:
let
  cfg = config.kanata;
in
{
  options = {
    kanata.enable = lib.mkEnableOption "kanata" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    services.kanata.enable = true;
    services.kanata.keyboards.main = {
      config = ''
        (defsrc
          caps
        )

        (defalias
          escctrl (tap-hold 100 100 esc lctrl)
        )

        (deflayer base
          @escctrl
        )
      '';
    };
  };
}
