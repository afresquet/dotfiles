{
  flake.modules.homeManager.swayosd =
    {
      config,
      pkgs,
      ...
    }:
    let
      c = config.lib.stylix.colors.withHashtag;
    in
    {

      # On-screen popup for the volume, mic and brightness keys (bound in Hyprland).
      config = {
        services.swayosd = {
          enable = true;
          # Low on the screen, like most OSDs.
          topMargin = 0.85;
          # Matches rofi and Waybar: dark base, 10px corners, blue accent.
          stylePath = pkgs.writeText "swayosd-style.css" ''
            window#osd {
              border-radius: 12px;
              border: 2px solid ${c.base0D};
              background: alpha(${c.base00}, 0.85);
            }

            window#osd #container {
              margin: 14px 18px;
            }

            window#osd image,
            window#osd label {
              color: ${c.base05};
              font-family: "${config.stylix.fonts.monospace.name}";
            }

            window#osd progressbar:disabled,
            window#osd image:disabled {
              opacity: 0.4;
            }

            window#osd progressbar,
            window#osd segmentedprogress {
              min-height: 6px;
              border-radius: 999px;
              background: transparent;
              border: none;
            }

            window#osd trough,
            window#osd segment {
              min-height: inherit;
              border-radius: inherit;
              border: none;
              background: ${c.base02};
            }

            window#osd progress,
            window#osd segment.active {
              min-height: inherit;
              border-radius: inherit;
              border: none;
              background: ${c.base0D};
            }
          '';
        };
      };
    };
}
