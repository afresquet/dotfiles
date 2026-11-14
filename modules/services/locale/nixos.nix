{
  # Set your time zone.
  time.timeZone = "Europe/Madrid";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  # Configure keymap in X11
  services.xserver = {
    enable = true;
    xkb = {
      layout = "us,ua";
      variant = "altgr-intl,";
      options = "ctrl:nocaps,lv3:ralt_switch,grp:alt_shift_toggle";
    };
  };
}
