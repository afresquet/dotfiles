# Home-Server: post-rebuild manual setup

Everything in this host's Nix config gets you to "services running, ports
firewalled, secrets decrypted, reverse proxy serving." Each app on top of that
manages its own state in its own database, so a few things have to be clicked
through in the web UIs the first time. This file is the checklist.

All hostnames below assume you're hitting them from a Tailscale-connected
device, with Pi-hole acting as the tailnet DNS.

## 0. Disk

`/mnt/hdd` is mounted from `/dev/sda1` (label `hdd`). If you ever need to wipe
and recreate the partition:

```sh
sudo wipefs -a /dev/sda
sudo sgdisk --zap-all /dev/sda
sudo sgdisk -n 1:0:0 -t 1:8300 -c 1:"hdd" /dev/sda
sudo partprobe /dev/sda
sudo mkfs.ext4 -F -L hdd /dev/sda1
```

The `hdd` label is what `fileSystems."/mnt/hdd"` in `configuration.nix`
references, so any new disk just needs that label.

## 1. agenix secrets

Edit each from the dotfiles repo (`EDITOR` is set to Helix via home-manager):

```sh
cd ~/dotfiles/secrets
agenix -e <name>.age
```

| Secret                          | Content (one line)                                         |
|---------------------------------|------------------------------------------------------------|
| `tailscale-auth.age`            | tailscale auth key (`tskey-auth-...`)                      |
| `pihole-webpassword.age`        | `FTLCONF_webserver_api_password=YOUR_PASSWORD`             |
| `qbittorrent-webuipw.age`       | the PBKDF2 hash *only* (see qBittorrent section below)     |

After creating any new `.age` file: `git add` it so the flake can see it, then
`nixos-rebuild switch`.

## 2. Tailscale tailnet DNS

In the [Tailscale admin console](https://login.tailscale.com/admin/dns):

- **DNS → Nameservers → Add nameserver → Custom**: the Pi's tailscale IP
  (find with `tailscale ip -4` on the Pi — currently `100.85.40.30`)
- Toggle **Override local DNS** on

This makes all tailnet clients route DNS through Pi-hole. The
`pihole.home-server`, `home-assistant.home-server`, etc. records are generated
declaratively via `FTLCONF_dns_hosts`, so no Pi-hole UI clicking needed.

## 3. Router (Livebox 7)

- Admin UI: `http://192.168.1.1` → Advanced settings → DHCP → Static leases
- Add a reservation for the Pi's wired MAC (`ip -br link show eth0` on Pi).
- Pick an IP outside the dynamic DHCP pool.

## 4. Pi-hole

Reachable as `http://home-server/` (Tailscale MagicDNS aliases bare hostname to
the Pi-hole vhost) or `http://pihole.home-server/`.

- Login password is whatever's in `pihole-webpassword.age`.
- No other config required — DNS records, upstreams, listening mode all
  declarative in `modules/nixos/services/pihole.nix`.

## 5. Home Assistant

URL: `http://home-assistant.home-server/`

1. First-run wizard: create admin user, pick location/timezone.
2. Skip integration prompts — set those up later.
3. Add the trusted-proxy block to `/var/lib/home-assistant/configuration.yaml`
   so HA accepts requests from caddy:

   ```sh
   sudo tee -a /var/lib/home-assistant/configuration.yaml > /dev/null <<'EOF'

   http:
     use_x_forwarded_for: true
     trusted_proxies:
       - 127.0.0.1
   EOF
   sudo systemctl restart podman-home-assistant.service
   ```

   (HA is the container-based service in this stack; everything else is native.)

## 6. qBittorrent

URL: `http://torrent.home-server/`

First-time password bootstrap (only needed for the very first run, or if you
ever wipe `qbittorrent-webuipw.age`):

1. Get the temp password from the journal:

   ```sh
   journalctl -u qbittorrent.service | grep -i 'temporary password'
   ```

2. Log in with `admin` + temp password.
3. **Tools → Options → Web UI → Authentication**: set your real password, save.
4. Read the resulting PBKDF2 hash from the on-disk config:

   ```sh
   sudo grep 'Password_PBKDF2' /mnt/hdd/qbittorrent/qBittorrent/config/qBittorrent.conf
   ```

   You'll see something like:
   `WebUI\Password_PBKDF2="@ByteArray(salt:hash)"`.
5. `agenix -e ~/dotfiles/secrets/qbittorrent-webuipw.age` and paste **only** the
   content between `@ByteArray(` and `)` — *not* the `@ByteArray(...)` wrapper
   or the surrounding quotes. One line, no trailing newline.
6. `nixos-rebuild switch && sudo systemctl restart qbittorrent.service`.

From now on the password persists across rebuilds — the wrapper module
substitutes the agenix-decrypted hash into `qBittorrent.conf` at start.

Everything else (save path, seeding limits, host header validation) is
declarative in `modules/nixos/services/qbittorrent.nix`.

## 7. Jellyfin

URL: `http://jellyfin.home-server/` (or `http://<lan-ip>:8096/` for casting from
TVs / phones on the LAN).

1. First-run wizard: pick language, create admin user.
2. Dashboard → **Libraries → Add Media Library**, one for each type:

   | Display name | Content type | Folder                    |
   |--------------|--------------|---------------------------|
   | Movies       | Movies       | `/mnt/hdd/media/movies`   |
   | TV           | Shows        | `/mnt/hdd/media/tv`       |
   | Music        | Music        | `/mnt/hdd/media/music`    |
   | Books        | Books        | `/mnt/hdd/media/books`    |

3. For each library: **Advanced → ☑ Enable Real-time Monitoring** so new files
   from Sonarr/Radarr/etc. show up within seconds rather than waiting for the
   hourly scan.

## 8. Prowlarr

URL: `http://prowlarr.home-server/`

1. First-run: create user/password.
2. **Indexers → +** → add the trackers you want (1337x, EZTV, YTS, etc.).
   Click **Test** before saving.
3. For Cloudflare-protected indexers (1337x, etc.):
   - **Settings → Indexers → Indexer Proxies → +** → FlareSolverr
   - Name: `flaresolverr`, Host: `http://127.0.0.1:8191`, Tags: add `cf`
   - Edit each protected indexer → add the `cf` tag → save.
4. **Settings → Apps → +** → add each *arr Prowlarr should sync indexers to:

   | App     | App URL                  | Use Sonarr/Radarr's API key from |
   |---------|--------------------------|----------------------------------|
   | Sonarr  | `http://127.0.0.1:8989`  | Sonarr → Settings → General → Security |
   | Radarr  | `http://127.0.0.1:7878`  | same path in Radarr              |
   | Lidarr  | `http://127.0.0.1:8686`  | same path in Lidarr              |
   | Readarr | `http://127.0.0.1:8787`  | same path in Readarr             |

   For all of them, **Prowlarr Server** stays `http://127.0.0.1:9696` (Prowlarr's
   own URL — used for callbacks).

## 9. Sonarr / Radarr / Lidarr / Readarr

Each has its own UI:

| App     | URL                            | Root folder              |
|---------|--------------------------------|--------------------------|
| Sonarr  | `http://sonarr.home-server/`   | `/mnt/hdd/media/tv`      |
| Radarr  | `http://radarr.home-server/`   | `/mnt/hdd/media/movies`  |
| Lidarr  | `http://lidarr.home-server/`   | `/mnt/hdd/media/music`   |
| Readarr | `http://readarr.home-server/`  | `/mnt/hdd/media/books`   |

For **each** app:

1. First-run: create user/password.
2. **Settings → Media Management → Root Folders → +** → add the path from the
   table above.
3. **Settings → Media Management** → toggle **Show Advanced** at the top → verify
   **Use Hardlinks instead of Copy** is checked. (Should be on by default; if
   it's off, hardlinks fall back to copies and disk usage doubles.)
4. **Settings → Download Clients → + → qBittorrent**:
   - Host `127.0.0.1`, Port `8080`
   - Username / Password: the qBittorrent admin credentials from agenix
   - Category: `sonarr` / `radarr` / `lidarr` / `readarr` respectively (the app
     auto-creates the category in qBittorrent)
5. **Settings → Indexers** — should auto-populate from Prowlarr's sync. If not,
   trigger a manual sync from the Prowlarr → Apps page.

### Recovery: lost a Sonarr/Radarr password

```sh
sudo systemctl stop sonarr.service   # or radarr, lidarr, readarr
sudo sed -i 's|<AuthenticationMethod>.*</AuthenticationMethod>|<AuthenticationMethod>None</AuthenticationMethod>|' \
  /var/lib/sonarr/.config/NzbDrone/config.xml
sudo systemctl start sonarr.service
```

Then hit the URL, get into the unauthenticated UI, set a new password under
Settings → General → Security, flip Authentication back to **Forms**.

## 10. Bazarr

URL: `http://bazarr.home-server/`

1. Default login: `admin` / `admin` — **change immediately** in
   Settings → General.
2. **Settings → Sonarr** → enable → URL `http://127.0.0.1:8989`, paste Sonarr's
   API key.
3. **Settings → Radarr** → enable → URL `http://127.0.0.1:7878`, paste Radarr's
   API key.
4. **Settings → Languages**: pick the subtitle languages you want and the
   default profile.
5. **Settings → Providers**: add OpenSubtitles, Subscene, etc. (some need
   accounts).

## 11. Jellyseerr

URL: `http://jellyseerr.home-server/`

1. First-run: **Sign in with Jellyfin** → enter
   - Jellyfin URL: `http://127.0.0.1:8096`
   - Username + password: your Jellyfin admin (not a separate Jellyseerr account)
2. **Sync Libraries**: pick all four (Movies, TV, Music, Books).
3. **Settings → Services → Sonarr → +**:
   - Hostname `127.0.0.1`, port `8989`, paste Sonarr's API key
   - Default Quality Profile and Root Folder (`/mnt/hdd/media/tv`)
4. **Settings → Services → Radarr → +**: same with port `7878`, root folder
   `/mnt/hdd/media/movies`.

After this the request loop works end-to-end:

```
Jellyseerr → Sonarr/Radarr → Prowlarr → indexer → qBittorrent
  → /mnt/hdd/downloads/torrents → *arr hardlinks to /mnt/hdd/media/...
  → Jellyfin picks up via real-time monitoring
```

## Notes / gotchas

- **Hardlink ownership**: qBittorrent runs with `UMask=0002` so new files are
  `0664`. Combined with the `2775 root:media` perms on `/mnt/hdd/downloads`,
  this lets the *arr users (in the `media` group) hardlink into
  `/mnt/hdd/media/*` without tripping the kernel's `fs.protected_hardlinks`
  check. Don't change qBittorrent's UMask back to defaults or hardlinks will
  silently fall back to copies.
- **Seeding policy**: 1.0 ratio OR 48h, then remove + delete files. Declared in
  `qbittorrent.nix`. Adjust there, not in the UI (UI changes get clobbered on
  next service restart by `serverConfig`).
- **API keys**: not declarative. Each app generates its own on first run; if you
  ever wipe `/var/lib/<app>` you'll have to re-paste them into the apps that
  consume them (Prowlarr → all *arr, Bazarr → Sonarr/Radarr, Jellyseerr →
  Sonarr/Radarr).
- **`home-server` (bare hostname)**: aliased on the Pi-hole vhost in caddy so
  Tailscale MagicDNS users have a path in even when subdomain DNS isn't working
  yet. Don't remove that alias.
