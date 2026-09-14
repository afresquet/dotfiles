# Waybar 0.15.0 expects Hyprland's pre-0.56 numeric workspace IDs and legacy
# dispatcher commands. This patch adapts its workspace IPC handling to the
# address-based schema and Lua dispatcher. Drop it once nixpkgs ships both
# upstream compatibility fixes.
final: prev: {
  waybar = prev.waybar.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./patches/waybar-lua-dispatch.patch ];
  });
}
