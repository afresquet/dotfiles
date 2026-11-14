{
  lib,
  config,
  pkgs,
  inputs,
  isLinux,
  ...
}:
let
  cfg = config.zen-browser;
in
{
  imports = [ inputs.zen-browser.homeModules.beta ];

  options.zen-browser.enable = lib.mkEnableOption "Zen Browser" // {
    default = isLinux;
  };

  config = lib.mkIf cfg.enable {
    programs.zen-browser = {
      enable = true;
      profiles.default = { };
    };

    stylix.targets.zen-browser.profileNames = [ "default" ];

    browser = lib.mkDefault config.programs.zen-browser.finalPackage;

    home.activation.defaultBrowser = lib.hm.dag.entryAfter [ "installPackages" "linkGeneration" ] ''
      run env -u BROWSER \
        PATH=${config.home.profileDirectory}/bin:$PATH \
        XDG_DATA_DIRS=${config.home.profileDirectory}/share \
        ${pkgs.xdg-utils}/bin/xdg-settings set default-web-browser zen-beta.desktop
    '';
  };
}
