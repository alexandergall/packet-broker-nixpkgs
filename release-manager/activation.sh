## Implementation of the activate()/deactivate() functions of the
## standard release-manager provided by bf-sde-nixpkgs. It is sourced
## by the release-manager script.

SYSTEMD_DIR=/etc/systemd/system
CONFIG_DIR=/etc/packet-broker
CONFIG=$CONFIG_DIR/config.json
SCHEMA=$CONFIG_DIR/schema.json
SNMP_CONFIG_DIR=/etc/snmp
SNMPD_CONFIG=$SNMP_CONFIG_DIR/snmpd.conf
IFINDEX=$SNMP_CONFIG_DIR/ifindex
SNMP_STATE_DIR=/var/lib/snmp
INTERFACE_CONFIG=$SNMP_STATE_DIR/interface.conf
SHELL_PROFILE=/etc/profile.d/packet-broker.sh

## Use the native systemctl command if possible to avoid issues with
## diverging versions of systemd from the native packages and
## systemctl from nixpkgs
shopt -s expand_aliases
[ -x /bin/systemctl ] && alias systemctl=/bin/systemctl

activate () {
    check_root
    INFO "Enabling services"
    for service in $PROFILE$SYSTEMD_DIR/*.service; do
        ln -fs $service $SYSTEMD_DIR
        systemctl enable $(basename $service)
    done
    ! ischroot && systemctl daemon-reload
    for dir in $CONFIG_DIR $SNMP_CONFIG_DIR $SNMP_STATE_DIR; do
        [ -d $dir ] || mkdir -p $dir
    done
    for file in $SCHEMA $IFINDEX $INTERFACE_CONFIG; do
        ## For some weird reason, the Snabb SNMP agent barfs
        ## when doing a stat() on the ifindex file in the Nix
        ## store. So, instead of linking to the file, we copy
        ## it.  Need to figure out what exactly the problem is.
        if [ $file == $IFINDEX ]; then
            cp $PROFILE$file $file
        else
            ln -fs $PROFILE$file $file
        fi
    done
    for config in $CONFIG $SNMPD_CONFIG; do
        [ -e $config ] || cp $PROFILE$config $config
    done
    if [ ! -e $SHELL_PROFILE ]; then
        echo PATH=$PROFILE/bin:\$PATH >$SHELL_PROFILE
    fi
    if ! ischroot; then
        INFO "Starting services"
        systemctl start packet-broker snmpd
    fi
}

deactivate () {
    check_root
    INFO "Stopping services"
    systemctl stop snmpd packet-broker || true
    INFO "Disabling services"
    for service in $PROFILE/$SYSTEMD_DIR/*.service; do
        systemctl disable $(basename $service) || true
    done
    INFO "Unloading kernel modules"
    for module in $(lsmod | awk '{print $1}'); do
        [[ $module =~ bf_ ]] && rmmod $module || true
    done
}
