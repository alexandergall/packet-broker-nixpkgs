SHELL=/bin/bash
PROFILE = /nix/var/nix/profiles/per-user/root/packet-broker
CONFIG_DIR = /etc/packet-broker
CONFIG = $(CONFIG_DIR)/config.json
SCHEMA = $(CONFIG_DIR)/schema.json
INSTALL_ARGS =
PATH +=:/nix/var/nix/profiles/default/bin

install:
	nix-env -f . -p $(PROFILE) -r -i -A install $(INSTALL_ARGS)

activate: install
	@for service in $(PROFILE)/*.service; do \
	    ln -fs $$service /etc/systemd/system; \
	    systemctl enable $$(basename $$service); \
	    systemctl daemon-reload; \
	done; \
	mkdir -p /etc/packet-broker; \
	if [ ! -e $(CONFIG) ]; then \
	    echo "Installing default configuration"; \
	    cp $(PROFILE)$(CONFIG) $(CONFIG); \
	fi; \
	if ! $$(test -f $(SCHEMA) && diff $(SCHEMA) $(PROFILE)$(SCHEMA) >/dev/null); then \
	    echo "Installing JSON schema"; \
	    cp $(PROFILE)$(SCHEMA) $(SCHEMA); \
	fi; \
	echo 'PATH=$(PROFILE)/bin:$$PATH' >/etc/profile.d/packet-broker

deactivate:
	@systemctl stop packet-broker; \
	if [ -e $(PROFILE) ]; then \
	    for service in $(PROFILE)/*.service; do \
	        systemctl disable $$(basename $$service); \
	    done; \
	fi

remove: deactivate
	rm -rf $(CONFIG_DIR)
	rm -f /etc/profile.d/packet-broker
	rm -f $(PROFILE)*
