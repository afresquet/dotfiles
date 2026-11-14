{
  flake.modules.homeManager.rofi =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    {
      config = lib.mkMerge [
        # The theme below uses Stylix's colors itself; its stock theme is plain.
        # Disabled even where rofi is off so Stylix doesn't load the target.
        { stylix.targets.rofi.enable = false; }

        {
          programs.rofi = {
            enable = true;
            settings = {
              font = "${config.stylix.fonts.monospace.name} 11";
              show-icons = true;
              # Same icon theme as GTK (set through Stylix).
              icon-theme = config.stylix.icons.dark;
              display-drun = "󰀻";
              display-run = "󰆍";
              display-emoji = "󰞅";
              drun-display-format = "{name}";
            };

            theme =
              let
                inherit (config.lib.formats.rasi) mkLiteral;
                c = config.lib.stylix.colors;
                rgba =
                  color: alpha:
                  mkLiteral "rgba(${c."${color}-rgb-r"}, ${c."${color}-rgb-g"}, ${c."${color}-rgb-b"}, ${toString alpha}%)";
              in
              {
                "*" = {
                  bg = rgba "base00" 92;
                  surface = mkLiteral c.withHashtag.base01;
                  selected = mkLiteral c.withHashtag.base02;
                  muted = mkLiteral c.withHashtag.base03;
                  fg = mkLiteral c.withHashtag.base05;
                  # Same blue as Hyprland's active window border.
                  accent = mkLiteral c.withHashtag.base0D;
                  urgent = mkLiteral c.withHashtag.base08;

                  background-color = mkLiteral "transparent";
                  text-color = mkLiteral "@fg";
                };

                window = {
                  width = mkLiteral "640px";
                  padding = mkLiteral "16px";
                  border = mkLiteral "2px";
                  border-radius = mkLiteral "12px";
                  border-color = mkLiteral "@accent";
                  background-color = mkLiteral "@bg";
                };

                mainbox = {
                  spacing = mkLiteral "12px";
                  children = map mkLiteral [
                    "inputbar"
                    "message"
                    "listview"
                  ];
                };

                inputbar = {
                  padding = mkLiteral "10px 14px";
                  spacing = mkLiteral "10px";
                  border-radius = mkLiteral "8px";
                  background-color = mkLiteral "@surface";
                  children = map mkLiteral [
                    "prompt"
                    "entry"
                  ];
                };
                prompt.text-color = mkLiteral "@accent";
                entry = {
                  placeholder = "Search…";
                  placeholder-color = mkLiteral "@muted";
                  cursor = mkLiteral "text";
                };

                message = {
                  padding = mkLiteral "8px 14px";
                  border-radius = mkLiteral "8px";
                  background-color = mkLiteral "@surface";
                };

                listview = {
                  lines = 8;
                  columns = 1;
                  spacing = mkLiteral "4px";
                  fixed-height = false;
                  scrollbar = false;
                };

                element = {
                  padding = mkLiteral "8px 12px";
                  spacing = mkLiteral "12px";
                  border-radius = mkLiteral "8px";
                };
                "element selected" = {
                  background-color = mkLiteral "@selected";
                  text-color = mkLiteral "@accent";
                };
                "element urgent".text-color = mkLiteral "@urgent";
                element-icon = {
                  size = mkLiteral "24px";
                  text-color = mkLiteral "inherit";
                };
                element-text = {
                  vertical-align = mkLiteral "0.5";
                  text-color = mkLiteral "inherit";
                  highlight = mkLiteral "bold";
                };
              };
          };

          home.packages = [ pkgs.rofimoji ];
        }
      ];
    };
}
