#!/bin/bash
version=$(cat ./version)
versionID=$(cat ./version.id)
profile=$(cat ./profile)
kernelRelease=$(uname -r)

PATH=/nix/var/nix/profiles/default/bin:@PATH@

error () {
    echo "ERROR: $1"
    exit 1
}

echo "Installing packet broker release $version (Id: $versionID)"\
     "for kernel $kernelRelease in $profile"
[ $(id -u) == 0 ] || error "Please run this command as root"

[ -d $kernelRelease ] || error "Unsupported kernel"
kernelIDs=$kernelRelease/*
if [ $(echo $kernelIDs | wc -w) -gt 1 ]; then
    echo "Modules for $kernelRelease are provided by multiple packages:"
    for id in kernelIDs; do
	echo $(basename $id)
    done
    [ -n "$KERNEL_ID" ] || \
	error "Please set KERNEL_ID to one of "\
	      "the values above to select a particular package"
    closureInfo=$kernelRelease/$KERNEL_ID
    [ -d  $closureInfo ] || \
	error "KERNEL_ID: invalid value $KERNEL_ID"
else
    closureInfo=$kernelIDs
fi

echo "Copying store paths"
tar xf store-paths.tar
for path in $(cat $closureInfo/store-paths); do
    path=$(echo $path | sed -e 's,^/,,')
    rsync -a $path /nix/store
done

echo "Registering paths in DB"
cat $closureInfo/registration | nix-store --load-db

echo "Installing the service in $profile"
current_gen () {
    [ -e $profile ] || echo ""
    echo $(readlink $profile | sed -e 's/.*-\([0-9]*\)-link$/\1/')
}

gen=$(current_gen)
nix-env -p $profile -i -r $(cat $closureInfo/rootPaths)
echo
echo "Installation completed"
if [ -n "$gen" ]; then
    if [ $(current_gen) != $gen ]; then
	nix-env -p $profile --rollback
	echo "Use \"release-manager --switch-to-generation $gen\" to switch to this release"
    else
	echo -n "The new release is identical to that "
        echo -n "in the latest generation ($gen) of the profile, "
	echo    "nothing changed"
    fi
fi

echo
echo "Currently installed releases:"
$profile/bin/release-manager --list-installed
