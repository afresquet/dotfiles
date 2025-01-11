{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.helix;
in
{
  options = {
    helix.enable = lib.mkEnableOption "Helix" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
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
            left = [
              "mode"
              "spinner"
              "version-control"
              "file-name"
            ];
            right = [
              "diagnostics"
              "selections"
              "position"
              "position-percentage"
              "file-encoding"
            ];
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

          end-of-line-diagnostics = "hint";
          inline-diagnostics.cursor-line = "warning";
        };

        keys.normal = {
          esc = [
            "collapse_selection"
            "keep_primary_selection"
          ];
        };
      };

      languages = {
        language = [
          {
            name = "nix";
            formatter = {
              command = "nixfmt";
            };
            auto-format = true;
          }

          {
            name = "html";
            formatter = {
              command = "prettier";
              args = [
                "--parser"
                "html"
              ];
            };
          }

          {
            name = "css";
            formatter = {
              command = "prettier";
              args = [
                "--parser"
                "css"
              ];
            };
          }

          {
            name = "json";
            formatter = {
              command = "prettier";
              args = [
                "--parser"
                "json"
              ];
            };
          }

          {
            name = "javascript";
            formatter = {
              command = "prettier";
              args = [
                "--parser"
                "typescript"
              ];
            };
            auto-format = true;
          }

          {
            name = "typescript";
            formatter = {
              command = "prettier";
              args = [
                "--parser"
                "typescript"
              ];
            };
            auto-format = true;
          }

          {
            name = "tsx";
            formatter = {
              command = "prettier";
              args = [
                "--parser"
                "typescript"
              ];
            };
            auto-format = true;
          }

          {
            name = "go";
            formatter = {
              command = "goimports";
            };
            auto-format = true;
          }

          {
            name = "toml";
            formatter = {
              command = "taplo";
              args = [
                "fmt"
                "-"
              ];
            };
          }

          {
            name = "python";
            language-servers = [
              "pyright"
              "ruff"
            ];
            formatter = {
              command = "black";
              args = [
                "--line-length"
                "88"
                "--quiet"
                "-"
              ];
            };
          }

          {
            name = "sql";
            formatter.command = "sleek";
            auto-format = true;
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

          pyright.config = {
            python.analisis.typeCheckingMode = "basic";
          };

          ruff = {
            command = "ruff-lsp";
            config.settings.args = [
              "--ignore"
              "E501"
            ];
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
        nixfmt-rfc-style
        # rust
        rust-analyzer
        # html css json
        vscode-langservers-extracted
        nodePackages.prettier
        # javascript typescript
        typescript
        nodePackages.typescript-language-server
        # bash
        bash-language-server
        # docker
        dockerfile-language-server-nodejs
        # markdown
        marksman
        # toml
        taplo
        # yaml
        yaml-language-server
        # python
        pyright
        ruff-lsp
        black
        # sql
        sleek
        # lldb
        lldb
      ];
    };
  };
}
