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
    system.activationScripts.postActivation.text = lib.mkAfter ''
      if ! launchctl print system/com.apple.screensharing >/dev/null 2>&1; then
        echo "enabling Screen Sharing..."
        launchctl enable system/com.apple.screensharing
        launchctl bootstrap system /System/Library/LaunchDaemons/com.apple.screensharing.plist
      fi
    '';
  };
}
