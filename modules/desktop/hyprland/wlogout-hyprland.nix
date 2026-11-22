{ self, ... }:
{
  # Hyprland tells the power menu the focused monitor's size, so it centers
  # there.
  flake.modules.homeManager.wlogout-hyprland =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    {
      imports = with self.modules.homeManager; [
        wlogout
        hyprland
      ];

      wlogout.focusedOutputSize = lib.removeSuffix "\n" ''
        ${lib.getExe' config.wayland.windowManager.hyprland.finalPackage "hyprctl"} monitors -j |
          ${lib.getExe pkgs.jq} -r '.[] | select(.focused) | "\((.width / .scale) | floor) \((.height / .scale) | floor)"'
      '';
    };
}
