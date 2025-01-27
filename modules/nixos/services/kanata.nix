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
      extraDefCfg = "process-unmapped-keys yes";

      config = ''
        (defsrc
          caps a s d f     j k l ;
                         n
        )

        (defvar
          tap-time 100
          hold-time 150
        )

        (defalias
          escctrl (tap-hold 100 100 esc caps)
          a (tap-hold $tap-time $hold-time a lmet)
          s (tap-hold $tap-time $hold-time s lalt)
          d (tap-hold $tap-time $hold-time d lsft)
          f (tap-hold $tap-time $hold-time f lctl)
          j (tap-hold $tap-time $hold-time j rctl)
          k (tap-hold $tap-time $hold-time k rsft)
          l (tap-hold $tap-time $hold-time l ralt)
          ; (tap-hold $tap-time $hold-time ; rmet)
          ñ (tap-hold 500 500 n (unicode ñ))
        )

        (deflayer base
          @escctrl @a @s @d @f @j @k @l @;
                              @ñ
        )
      '';
    };
  };
}
