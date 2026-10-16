{ config, lib, ... }:
let
  cfg = config.screensharing;
in
{
  options = {
    screensharing.enable = lib.mkEnableOption "macOS Screen Sharing (VNC/ARD)" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    # NOTE: this only starts the daemon. The Screen Recording (TCC) grant for
    # ScreensharingAgent is only made by toggling Screen Sharing off/on in
    # System Settings > General > Sharing; without it clients get a black screen.
    system.activationScripts.postActivation.text = lib.mkAfter ''
      if ! launchctl print system/com.apple.screensharing >/dev/null 2>&1; then
        echo "enabling Screen Sharing..."
        launchctl enable system/com.apple.screensharing
        launchctl bootstrap system /System/Library/LaunchDaemons/com.apple.screensharing.plist
      fi
    '';
  };
}
