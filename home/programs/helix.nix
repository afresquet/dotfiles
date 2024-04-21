{ pkgs, ... }: {
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
        auto-format = true;

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
      language = [
        {
          name = "nix";
          formatter = { command = "nixpkgs-fmt"; };
          auto-format = true;
        }

        {
          name = "html";
          formatter = { command = "prettier"; args = [ "--parser" "html" ]; };
        }

        {
          name = "css";
          formatter = { command = "prettier"; args = [ "--parser" "css" ]; };
        }

        {
          name = "json";
          formatter = { command = "prettier"; args = [ "--parser" "json" ]; };
        }

        {
          name = "javascript";
          formatter = { command = "prettier"; args = [ "--parser" "typescript" ]; };
          auto-format = true;
        }

        {
          name = "typescript";
          formatter = { command = "prettier"; args = [ "--parser" "typescript" ]; };
          auto-format = true;
        }

        {
          name = "tsx";
          formatter = { command = "prettier"; args = [ "--parser" "typescript" ]; };
          auto-format = true;
        }

        {
          name = "go";
          formatter = { command = "goimports"; };
          auto-format = true;
        }

        {
          name = "toml";
          formatter = { command = "taplo"; args = [ "fmt" "-" ]; };
        }
      ];

      language-server = {
        rust-analyzer.config = {
          check.command = "clippy";
        };

        yaml-language-server.config.yaml = {
          format.enable = true;
          validation = true;
          schemas = {
            "https://json.schemastore.org/github-workflow.json" = ".github/workflows/*.{yml,yaml}";
          };
        };
      };
    };

    themes = {
      catppuccin_mocha = {
        inherits = "catppuccin_mocha";
        "ui.background" = { };
      };
    };

    extraPackages = with pkgs; [
      # nix
      nil
      nixpkgs-fmt
      # rust
      rust-analyzer
      # html css json
      vscode-langservers-extracted
      nodePackages.prettier
      # javascript typescript
      typescript
      nodePackages.typescript-language-server
      # bash
      nodePackages.bash-language-server
      # docker
      dockerfile-language-server-nodejs
      # markdown
      marksman
      # toml
      taplo
      # yaml
      yaml-language-server
    ];
  };
}
