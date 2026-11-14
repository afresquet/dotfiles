{
  flake.modules.homeManager.kitty = _: {
    config = {
      programs.kitty = {
        enable = true;
        settings = {
          confirm_os_window_close = 0;
        };
      };
    };
  };
}
