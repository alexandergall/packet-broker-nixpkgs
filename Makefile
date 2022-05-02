gitDescribe=$(shell git describe --always)
ifneq ($(shell git status --porcelain),)
  gitTag = $(gitDescribe)-local-$(shell find . -type f ! -path "./.git/*" ! -name "result*" ! -name "*~" -exec sha256sum {} \; | sha256sum | cut -c1-6)
  $(info Repo is modified, using extended tag as release identifier: $(gitTag))
else
  gitTag = $(gitDescribe)
endif

onieInstaller:
	NIX_PATH= nix-build -j auto -A onieInstaller --argstr gitTag $(gitTag)

onieInstaller-SWITCH:
	NIX_PATH= nix-build -j auto -A onieInstaller --argstr gitTag $(gitTag) \
	  --arg onieUsers '{ansible = {useraddArgs = "-s /bin/bash"; sshPublicKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDS/xdgmacIpg2bpsdqFETevQKPqyi3Pmn9lDaHQ/QYsz7eqsZAX/Tn+0NBL6sVb4C5g2Qk9EzKPs1v1F3p5bwaDq08aC+cRgKndWwjpZxj/MV0HQhzC5NpfBcE0TS5nzLJFjEs2qxQorZ07PglsYLCTxhe0vI36ddvfM1VIhc0Wa+h97CPjfIWNWUSAKKhjznpyJKONwWcHeM15MCzow6riDrHo14DsnoW9T68h3Qcd1RUUPx5xG6vd9cZ/7bAqru44RdDq4FUpkmPK+W6VN7bRqOxXC1TbKbptpeITcQdiBWblNgao9bvOtpxjXd1uEU0h9oqCsMn0tjIIsFYT2Wz ansible";};}'

standaloneInstaller:
	NIX_PATH= nix-build -j auto -A standaloneInstaller --argstr gitTag $(gitTag)
	@set -e; \
	dest=/tmp/$@; \
	echo "Writing installer to $$dest\n"; \
	path=$$(readlink result); \
	rm -f $$dest; \
	echo '#!/bin/bash' >$$dest; \
	echo '[ $$(id -u) == 0 ] || { echo "Please run as root"; exit 1; }' >>$$dest; \
	echo 'echo "Installing installer closure"' >>$$dest; \
	echo '/nix/var/nix/profiles/default/bin/nix-store --import < <(tail -n+7 $$0 | xz -d)' >>$$dest; \
	echo $$path/installer.sh >>$$dest; \
	echo 'exit 0' >>$$dest; \
	echo "Generating installer closure"; \
	nix-store --export $$(nix-store -qR $$path) | xz -v -T0 >>$$dest; \
	chmod a+x $$dest

install:
	@echo "Building release manager"
	@NIX_PATH= nix-build -j auto -A release-manager
	@sudo ./result/bin/release-manager --install-local .
