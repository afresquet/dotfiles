# Only one MPRIS player plays at a time: when one starts, pause the others.
{
  flake.modules.homeManager.pause-other-players =
    { lib, pkgs, ... }:
    let
      script = pkgs.writeShellApplication {
        name = "pause-other-players";
        runtimeInputs = [ pkgs.playerctl ];
        text = ''
          playerctl --all-players --follow --format '{{playerInstance}} {{status}}' status 2>/dev/null |
            while read -r instance status; do
              # playerctld proxies whichever player is active; pausing it
              # would pause the one that just started.
              if [ "$status" != Playing ] || [ "$instance" = playerctld ]; then
                continue
              fi
              for other in $(playerctl --list-all 2>/dev/null); do
                if [ "$other" != "$instance" ] && [ "$other" != playerctld ] &&
                  [ "$(playerctl --player="$other" status 2>/dev/null)" = Playing ]; then
                  playerctl --player="$other" pause
                fi
              done
            done
        '';
      };
    in
    {
      systemd.user.services.pause-other-players = {
        Unit = {
          Description = "Pause other media players when one starts playing";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = lib.getExe script;
          Restart = "always";
          RestartSec = 2;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };
}
