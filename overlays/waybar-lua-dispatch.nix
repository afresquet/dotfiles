# Waybar 0.15.0 expects Hyprland's pre-0.56 numeric workspace IDs and legacy
# dispatcher commands. This patch adapts its workspace IPC handling to the
# address-based schema and Lua dispatcher. Upstream master has the fixes
# (Alexays/Waybar b591c8a and follow-ups) but no release includes them yet, so
# this throws on any waybar bump as a reminder to check and drop the patch.
final: prev: {
  waybar =
    if prev.waybar.version == "0.15.0" then
      prev.waybar.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ./patches/waybar-lua-dispatch.patch ];
      })
    else
      throw "waybar overlay: nixpkgs now ships ${prev.waybar.version}; check it includes Alexays/Waybar b591c8a and remove overlays/waybar-lua-dispatch.nix";
}
