{ pkgs, version, nixProfile, bf-sde, slice }:

let
  mkOnieInstaller = pkgs.callPackage (pkgs.fetchgit {
    url = "https://github.com/alexandergall/onie-debian-nix-installer";
    rev = "6997859";
    sha256 = "16adh3610a9pah3xwsz1ljp33g8llvfrahrc7l6hvnp6ihanyyjx";
  }) {};
  ## The kernel selected here must match the kernel provided by the
  ## bootstrap profile.
  rootPaths = builtins.attrValues (slice bf-sde.pkgs.kernel-modules.Debian10_9);
  postRootFsCreateCmd = pkgs.writeShellScript "packet-broker-install-profile" ''
    echo "Installing packet broker into ${nixProfile}"
    HOME=/tmp
    /nix/var/nix/profiles/default/bin/nix-env -p ${nixProfile} -i \
        ${pkgs.lib.strings.concatStringsSep " " rootPaths} --option sandbox false
    echo "Activating release"
    ${nixProfile}/bin/release-manager --activate-current
  '';
in mkOnieInstaller {
  inherit version rootPaths postRootFsCreateCmd;
  component = "packet-broker";
  bootstrapProfile = ./profile;
  binaryCaches = [ {
    url = "http://p4.cache.nix.net.switch.ch";
    key = "p4.cache.nix.net.switch.ch:cR3VMGz/gdZIdBIaUuh42clnVi5OS1McaiJwFTn5X5g=";
  } ];
  fileTree = ./files;
}
