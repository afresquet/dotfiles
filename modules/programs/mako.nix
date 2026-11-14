{
  flake.modules.homeManager.mako = _: {
    options = {
      # Off when SwayNotificationCenter handles notifications.
    };

    config = {
      services.mako = {
        enable = true;
        settings = {
          borderRadius = 5;
          borderSize = 2;
          layer = "overlay";
        };
      };
    };
  };
}
