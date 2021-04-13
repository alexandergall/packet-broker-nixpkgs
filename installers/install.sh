#!/bin/bash
set -e

partial_id=$(cat ./version)
PROFILE=$(cat ./profile)
kernelRelease=$(uname -r)

PATH=/nix/var/nix/profiles/default/bin:@PATH@
NIX_PATH=

error () {
    echo "ERROR: $1"
    exit 1
}

declare -A gens gens_by_id

gen_from_path () {
    echo $1 | sed -e 's/.*-\([0-9]*\)-link$/\1/'
}

for path in $PROFILE-*-link; do
    [ -h $path ] || continue
    id=$(cat $path/version):$(cat $path/slice)
    gen=$(gen_from_path $path)
    gens[$gen]=$id
    if [ -n "${gens_by_id[$id]}" ]; then
        echo "Generation $gen is duplicate of ${gens_by_id[$id]}, ignoring"
    else
        gens_by_id[$id]=$gen
    fi
done
current_gen=0
if [ -h $PROFILE ]; then
    current_gen=$(gen_from_path $(readlink $PROFILE))
fi

read version gitTag < <(echo $partial_id | tr ':' ' ')
echo "Installing packet broker release $version (Id: $partial_id)"\
     "for kernel $kernelRelease in $PROFILE"
[ $(id -u) == 0 ] || error "Please run this command as root"

[ -d $kernelRelease ] || error "Unsupported kernel"
kernelIDs=$kernelRelease/*
if [ $(echo $kernelIDs | wc -w) -gt 1 ]; then
    echo "Modules for $kernelRelease are provided by multiple packages:"
    for id in kernelIDs; do
        echo $(basename $id)
    done
    [ -n "$SDE_KERNEL_ID" ] || \
        error "Please set SDE_KERNEL_ID to one of "\
              "the values above to select a particular package"
    closureInfo=$kernelRelease/$SDE_KERNEL_ID
    [ -d  $closureInfo ] || \
        error "SDE_KERNEL_ID: invalid value $SDE_KERNEL_ID"
    kernel_id=$SDE_KERNEL_ID
else
    kernel_id=$(basename $kernelIDs)
    closureInfo=$kernelIDs
fi

id=${partial_id}:${kernel_id}:${kernelRelease}
if [ -n "${gens_by_id[$id]}" ]; then
    echo "This release is already installed as generation ${gens_by_id[$id]}:"
    $PROFILE/bin/release-manager --list-installed
    exit 1
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
new_gen=$(gen_from_path $(readlink $PROFILE))
if [ $current_gen -gt 0 ]; then
    nix-env -p $PROFILE --switch-generation $current_gen 2>/dev/null
    echo "Use \"release-manager --switch-to-generation $new_gen\" to switch to this release"
else
    echo "This is the first installation of the service."
    echo "Use \"$PROFILE/bin/release-manager --activate\" to start."
fi

echo "Currently installed releases:"
$PROFILE/bin/release-manager --list-installed