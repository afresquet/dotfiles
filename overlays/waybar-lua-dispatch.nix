# Waybar's hyprland/workspaces click handler sends the legacy string dispatch
# (`dispatch workspace name:<x>`), which Hyprland >= 0.54 with a Lua config
# rejects — it evaluates the argument as Lua, so clicking a workspace icon does
# nothing. Upstream fixed this in PR #5013 (merged, unreleased as of 0.15.0);
# this patch backports the fix by wrapping the dispatch in `hl.dsp.exec_raw`.
# Drop this overlay once nixpkgs ships a Waybar release that includes #5013.
final: prev: {
  waybar = prev.waybar.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./patches/waybar-lua-dispatch.patch ];
  });
}
