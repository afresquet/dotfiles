{
  # The group shared by everything that reads or writes the media library and
  # the downloads feeding it. Pinned because containers take it by number
  # (`--user`, PGID): their images have no "media" group. 984 is where dynamic
  # assignment first landed, so pinning it needed no chown.
  flake.modules.nixos.media-group.users.groups.media.gid = 984;
}
