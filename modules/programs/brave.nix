{ lib, config, pkgs, commonUtils, ... }: {
  options = {
    brave.enable = lib.mkEnableOption "Brave Browser";
  };

  config = {
    packages = lib.mkIf config.brave.enable [
      (commonUtils.waylandWrapper {
        name = "brave";
        inherit pkgs lib;
        extraArgs = [
          "--ozone-platform-hint=auto"
          "--enable-features=TouchpadOverscrollHistoryNavigation"
        ];
      })
    ];
  };
}
