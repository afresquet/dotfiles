{
  # Lets rootful podman containers run with `--userns=auto`: podman carves each
  # one a private uid/gid range out of the `containers` entry in /etc/subuid and
  # /etc/subgid, so the container's users (root included) are unprivileged host
  # uids that nothing else owns, instead of root or whoever has the same uid on
  # the host. The account itself never runs anything; it only names the range.
  flake.modules.nixos.podman-userns = {
    users = {
      users.containers = {
        isSystemUser = true;
        group = "containers";
        # The upper half of the uid space, podman's documented default, far
        # from any real or system account.
        subUidRanges = [
          {
            startUid = 2147483647;
            count = 2147483648;
          }
        ];
        subGidRanges = [
          {
            startGid = 2147483647;
            count = 2147483648;
          }
        ];
      };
      groups.containers = { };
    };
  };
}
