# dotfiles

Nix flake for every machine I use: two NixOS desktops, a Raspberry Pi
home server, a headless Mac mini on nix-darwin, and a work MacBook that
only gets home-manager.

| Host | Platform | System config | Home config |
|------|----------|---------------|-------------|
| `Alvaro-Desktop` | NixOS, x86_64 | `nixosConfigurations.Alvaro-Desktop` | `homeConfigurations."afresquet@Alvaro-Desktop"` |
| `Alvaro-Laptop` (Framework 13) | NixOS, x86_64 | `nixosConfigurations.Alvaro-Laptop` | `homeConfigurations."afresquet@Alvaro-Laptop"` |
| `Home-Server` (Raspberry Pi 5) | NixOS, aarch64 | `nixosConfigurations.Home-Server` | `homeConfigurations."pi@Home-Server"` |
| `Alvaros-Mac-mini` | nix-darwin, aarch64 | `darwinConfigurations.Alvaros-Mac-mini` | `homeConfigurations."afresquet@Alvaros-Mac-mini"` |
| work MacBook | macOS, aarch64 | none | `homeConfigurations."alvaro.fresquet@Alvaros-MacBook-Pro.local"` |

## Layout

- `flake.nix` wires inputs, hosts and the shared helpers; `utils.nix` holds
  the directory-import helpers every module tree uses.
- `hosts/<host>/` has one `settings.nix` (hostname, user, monitors, and
  other per-host facts declared in `hosts/settings.nix`), plus
  `configuration.nix` for the system and `home.nix` for home-manager.
  `hosts/configuration.nix` is shared by the NixOS desktops,
  `hosts/home-base.nix` by every home config and `hosts/home.nix` adds the
  desktop layer (GUI programs, Hyprland, Stylix).
- `modules/{nixos,darwin,home-manager}/` are categories of modules. Every
  module exposes a top-level `<name>.enable` option and is imported through
  its category's `default.nix`; `modules/shared/` holds option declarations
  used on more than one platform.
- `modules/nixos/services/` modules contribute to each other through
  `reverseProxy.services`, `dashboard.services`, `monitoring.exporters` and
  `monitoring.dashboards`; a module imports the module whose options it
  contributes to. The Mac's monitoring reads the Pi's evaluated config
  (`piConfig`) to build its Prometheus and Grafana provisioning.
- `pkgs/` are custom packages exposed as `packages.<system>` and through the
  `additions` overlay; `overlays/` holds patches to nixpkgs packages, each of
  which throws once the pinned version moves so it gets removed.
- `secrets/` is agenix: `keys.nix` lists the public keys, `agenix-rules.nix`
  says which keys decrypt which secret.

## Rebuilding

The `nh` aliases from `modules/home-manager/cli/nh.nix`, run from anywhere:

| Alias | Runs |
|-------|------|
| `noss` / `nost` / `nosb` | `nh os switch` / `test` / `boot` |
| `ndws` | `nh darwin switch` |
| `nhms` | `nh home switch` |
| `nca` | `nh clean all` |

The flake path comes from the `dotfilesDir` setting, which defaults to
`~/dotfiles`. The Pi's SD image is built by the GitHub workflow in
`.github/workflows/build-home-server.yml`; `hosts/home-server/README.md` is
the post-install checklist for its services.

## Secrets

```sh
cd secrets
agenix -e <name>.age
```

New secrets get an entry in `agenix-rules.nix` first, then `git add` so the
flake sees the file. Host keys come from `/etc/ssh/ssh_host_ed25519_key.pub`
on each box.

## Checks

`nix fmt` formats with nixfmt and `nix flake check` also runs statix and
deadnix (via treefmt-nix).
