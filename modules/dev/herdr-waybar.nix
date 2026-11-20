{ self, ... }:
{
  # Herdr never asks the compositor for attention, so Hyprland can't mark its
  # window urgent. Instead this service rewrites a stylesheet Waybar imports
  # (and live-reloads) to paint the herdr workspace like an urgent one while an
  # agent in the Herdr window is done or blocked.
  flake.modules.homeManager.herdr-waybar =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      css = "${config.xdg.cacheHome}/herdr-waybar.css";
      c = config.lib.stylix.colors.withHashtag;
      rule = "#workspaces button.herdr:not(.active) { background: ${c.base08}; color: ${c.base00}; }";
      watcher = pkgs.writeShellApplication {
        name = "herdr-waybar";
        runtimeInputs = [ pkgs.jq ];
        text = ''
          last="?"
          while :; do
            want=""
            # The app's view, not `hc ls`: the core keeps reporting `done`
            # after the agent has been looked at in the app.
            if ${lib.getExe config.herdr-desktop.package} ls 2>/dev/null |
              jq -e '[.. | objects | .status? | strings] | any(. == "blocked" or . == "done")' >/dev/null; then
              want=${lib.escapeShellArg rule}
            fi
            if [ "$want" != "$last" ]; then
              printf '%s\n' "$want" >${css}
              last=$want
            fi
            sleep 2
          done
        '';
      };
    in
    {
      imports = with self.modules.homeManager; [
        waybar
        herdr-desktop
      ];

      programs.waybar = {
        settings.mainBar.reload_style_on_change = true;
        style = lib.mkBefore ''@import "${css}";'';
      };

      # Waybar only watches imports that exist when it starts.
      home.activation.herdrWaybarCss = lib.hm.dag.entryAfter [ "writeBoundary" ] "run touch ${css}";

      systemd.user.services.herdr-waybar = {
        Unit = {
          Description = "Highlight the herdr workspace in Waybar when an agent needs attention";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = lib.getExe watcher;
          Restart = "always";
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };
}
