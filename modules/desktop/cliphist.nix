{
  flake.modules.homeManager.cliphist =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      cliphist = lib.getExe config.services.cliphist.package;
      rofi = lib.getExe config.programs.rofi.package;

      # Rofi list of past copies (newest first). Enter copies the entry again,
      # Delete removes it and reopens the list, Escape leaves the clipboard
      # alone. Rofi returns exit code 10 for its first custom key; Delete is
      # freed from deleting characters (Control+d still does).
      picker = pkgs.writeShellScriptBin "clipboard-history" ''
        while true; do
          pick=$(${cliphist} list | ${rofi} -dmenu -i -no-custom -no-show-icons \
            -display-columns 2 -p 󰅌 \
            -kb-delete-entry "" -kb-remove-char-forward "Control+d" \
            -kb-custom-1 "Delete")
          case $? in
            0)
              [ -n "$pick" ] && printf '%s\n' "$pick" | ${cliphist} decode | ${lib.getExe' pkgs.wl-clipboard "wl-copy"}
              exit 0
              ;;
            10) [ -n "$pick" ] && printf '%s\n' "$pick" | ${cliphist} delete ;;
            *) exit 0 ;;
          esac
        done
      '';
    in
    {
      options = {
        cliphist.picker = lib.mkOption {
          type = lib.types.package;
          default = picker;
          readOnly = true;
          internal = true;
        };
      };

      # Records everything copied (text and images); SUPER + SHIFT + V picks.
      config = {
        services.cliphist.enable = true;
        home.packages = [ picker ];
      };
    };
}
