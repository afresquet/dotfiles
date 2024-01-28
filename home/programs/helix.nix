{ pkgs, ... }:
let 
  prettier = parser: {
    formatter = {
      command = "prettier";
      args = [ "--parser" parser ];
    };
  }; 
in
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

      html = prettier "html";
      json = prettier "json";
      css = prettier "css";
      javascript = prettier "typescript";
      typescript = prettier "typescript";
      tsx = prettier "typescript";

      toml = {
        formatter = {
          command = "taplo";
          args = [ "fmt" "-" ];
        };
      };

      yaml = {
        language-server.yaml-language-server.config.yaml = {
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
        "ui.background" = {};
      };
    };
  };

  # lsp packages
  home.packages = with pkgs; [
    # rust
    rustup
    # nix
    nil
    nixpkgs-fmt
    # html css json
    vscode-langservers-extracted
    # javascript typescript
    typescript
    nodePackages.typescript-language-server
    # bash
    nodePackages.bash-language-server
    # docker
    dockerfile-language-server-nodejs
    # haskell
    haskell-language-server
    #lua
    lua-language-server
    # markdown
    marksman
    # svelte
    nodePackages.svelte-language-server
    # toml
    taplo
    # yaml
    yaml-language-server
  ];
}
