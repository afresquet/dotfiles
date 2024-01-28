{ pkgs, ... }:

{
  programs.helix = {
    enable = true;

    settings = {
      theme = "catppuccin_mocha";

      editor = {
        true-color = true;
        line-number = "relative";
        cursorline = true;
        color-modes = true;
        idle-timeout = 0;
        completion-trigger-len = 1;

        statusline = {
          left = [ "mode" "spinner" "version-control" "file-name" ];
          right = [ "diagnostics" "selections" "position" "position-percentage" "file-encoding" ];
        };

        lsp = {
          display-messages = true;
          display-inlay-hints = true;
        };

        cursor-shape = {
          insert = "bar";
          normal = "block";
          select = "underline";
        };

        file-picker.hidden = false;
        indent-guides.render = true;
      };

      keys.normal = {
        esc = [ "collapse_selection" "keep_primary_selection" ];
      };
    };

    languages = {
      rust = {
        language-server.rust-analyzer.config = {
          check.command = "clippy";
        };
      };

      nix = {
        formatter.command = "nixpkgs-fmt";
        auto-format = true;
      };

      html = {
        formatter = {
          command = "prettier";
          args = [ "--parser" "html" ];
        };
      };

      json = {
        formatter = {
          command = "prettier";
          args = [ "--parser" "json" ];
        };
      };

      css = {
        formatter = {
          command = "prettier";
          args = [ "--parser" "css" ];
        };
      };

      javascript = {
        formatter = {
          command = "prettier";
          args = [ "--parser" "typescript" ];
        };
      };

      typescript = {
        formatter = {
          command = "prettier";
          args = [ "--parser" "typescript" ];
        };
      };

      tsx = {
        formatter = {
          command = "prettier";
          args = [ "--parser" "typescript" ];
        };
      };
    };

    themes = {
      catppuccin_mocha = {
        inherits = "catppuccin_mocha";
        "ui.background" = {};
      };
    };
  };

  home.packages = with pkgs; [
    nil
    nixpkgs-fmt
  ];
}
