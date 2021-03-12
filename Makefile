install:
	nix-env -f . -p $${PB_PROFILE:-/nix/var/nix/profiles/per-user/$$USER/packet-broker} -r -i -A install
