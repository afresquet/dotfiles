{ self, ... }:
{
  # The control center buttons that only work under Hyprland: hyprsunset and
  # grimblast talk to it directly. They land between swaync's own.
  flake.modules.homeManager.swaync-hyprland =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      inherit (config.swaync.buttons) on toggle button;
      hyprsunset = lib.getExe pkgs.hyprsunset;
    in
    {
      imports = with self.modules.homeManager; [
        swaync
        hyprland
      ];

      services.swaync.settings.widget-config.buttons-grid.actions = [
        # Night light: hyprsunset runs only while it's on.
        (toggle "night-light" "󰖔"
          "if ${on}; then setsid ${hyprsunset} -t 4500 >/dev/null 2>&1 </dev/null & else pkill -x hyprsunset; fi"
          "pgrep -x hyprsunset >/dev/null && echo true || echo false"
        )
        (button "screenshot" "󰹑" "sleep 0.4\nSLURP_RECTS='' ${lib.getExe pkgs.grimblast} copysave area")
      ];
    };
}
