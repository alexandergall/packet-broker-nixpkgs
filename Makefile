gitDescribe=$(shell git describe --always)
ifneq ($(shell git status --porcelain),)
  gitTag = $(gitDescribe)-local-$(shell find . -type f ! -path "./.git/*" ! -name "result*" ! -name "*~" -exec sha256sum {} \; | sha256sum | cut -c1-6)
  $(info Repo is modified, using extended tag as release identifier: $(gitTag))
else
  gitTag = $(gitDescribe)
endif

onieInstaller:
	NIX_PATH= nix-build -j auto -A onieInstaller --argstr gitTag $(gitTag)

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
