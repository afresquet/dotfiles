{ self, ... }:
{
  # Waybar under Hyprland: its workspaces and submap on the left, its keyboard
  # layout at the head of the status group.
  flake.modules.homeManager.waybar-hyprland =
    { lib, config, ... }:
    {
      imports = with self.modules.homeManager; [
        waybar
        hyprland
      ];

      programs.waybar.settings.mainBar = {
        modules-left = [
          "hyprland/workspaces"
          "hyprland/submap"
        ];
        "group/status".modules = lib.mkBefore [ "hyprland/language" ];

        "hyprland/workspaces" = {
          disable-scroll = true;
          warp-on-scroll = false;
          sort-by = "id";
          format = "{icon}";
          format-icons = lib.mapAttrs (_: ws: ws.icon) config.hyprland.workspaces;
        };
        # Shown only while a submap (SUPER + O "open") is active.
        "hyprland/submap" = {
          format = "󰘳 {}";
          tooltip = false;
        };
        "hyprland/language" = {
          # Shows US or UA; hover for the full layout name. Alt+Shift switches
          # layouts, and clicking this indicator provides a mouse alternative.
          format = "󰌌 {short}";
          tooltip-format = "{long}\nAlt+Shift to switch";
          on-click = "hyprctl switchxkblayout current next";
        };
      };
    };
}
