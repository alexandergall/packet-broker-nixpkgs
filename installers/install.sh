#!/bin/bash
version=$(cat ./version)
versionID=$(cat ./version.id)
PROFILE=$(cat ./profile)
kernelRelease=$(uname -r)

PATH=/nix/var/nix/profiles/default/bin:@PATH@
NIX_PATH=

error () {
    echo "ERROR: $1"
    exit 1
}

declare -A gens gens_by_id

current_gen=0
if [ -h $PROFILE ]; then
    for path in $PROFILE-*-link; do
	[ -h $path ] || continue
	short_path=$(basename $path)
	gen=$(echo $short_path | sed -e 's/.*-\([0-9]*\)-link$/\1/')
	[ $gen -gt $current_gen ] && current_gen=$gen
	gens[$gen]=$short_path
	id=$(cat $path/version.id)
	gens_by_id[$id]=$gen
  done
fi

echo "Installing packet broker release $version (Id: $versionID)"\
     "for kernel $kernelRelease in $PROFILE"
[ $(id -u) == 0 ] || error "Please run this command as root"

if [ -n "${gens_by_id[$versionID]}" ]; then
    echo "This release is already installed as generation #${gens_by_id[$versionID]}:"
    $PROFILE/bin/release-manager --list-installed
    exit 1
fi

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

echo "Installing the service in $PROFILE"
nix-env -p $PROFILE -i -r $(cat $closureInfo/rootPaths)
echo
echo "Installation completed"
if [ $current_gen -gt 0 ]; then
    nix-env -p $PROFILE --rollback 2>/dev/null
    echo "Use \"release-manager --switch-to-generation $((current_gen + 1))\" to switch to this release"
else
    echo "This is the first installation of the service."
    echo "Use \"$PROFILE/bin/release-manager --activate\" to start."
fi

echo "Currently installed releases:"
$PROFILE/bin/release-manager --list-installed
