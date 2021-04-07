## When called from Hydra via release.nix or from "release-manager
## --installl-git", we get the result of "git describe" passed in as
## gitTag.
{ gitTag ? "WIP" }:

let
  pkgs = import (fetchTarball {
    url = https://github.com/alexandergall/bf-sde-nixpkgs/archive/v4.tar.gz;
    sha256 = "0nfg0k0n8sk1bfi6bi1rc9kp4x2kbg2jb9q2rb4ajdcjhqa2zf86";
  }) {
    overlays = import ./overlay;
  };

  ## Release version of the packet broker service.  The commit for the
  ## release is tagged with "release-<version>". The version should be
  ## bumped to the next planned release right after tagging.
  ##
  ## The release version is stored in the file "version" in the Nix
  ## profile of the service.  Tagged releases are the principal
  ## entities that are installable with the release-manager.  To make
  ## arbitrary commits installable as well, we also keep track of the
  ## Git commit as the unique ID for an installed service instance in
  ## the file "version.id" in the Nix profile.
  version = "1";
  versionFiles = {
    version = pkgs.writeTextDir "version" (version + "\n");
    version-id = pkgs.writeTextDir "version.id" (gitTag + "\n");
  };
  nixProfile = "/nix/var/nix/profiles/per-user/root/packet-broker";

  ## Build the main components with the latest SDE version
  bf-sde = pkgs.bf-sde.latest;
  src = pkgs.fetchFromGitHub {
    owner = "alexandergall";
    repo = "packet-broker";
    rev = "v1";
    sha256 = "1rfm286mxkws8ra92xy4jwplmqq825xf3fhwary3lgvbb59zayr9";
  };

  ## A release is a set of all derivations to be installed into the
  ## Nix profile for the service.  The moduleWrapper attribute depends
  ## on the kernel of the system on which the installation will take
  ## place. This function creates the release for one particular
  ## kernel.
  release = kernelModules:
    let
      packet-broker = pkgs.callPackage ./packet-broker.nix { inherit bf-sde src version; };
      configd = pkgs.callPackage ./configd.nix { inherit bf-sde src version; };
      release-manager = pkgs.callPackage ./release-manager { inherit version; };
      moduleWrapper = packet-broker.moduleWrapper' kernelModules;
      services = import ./services {
        ## Make moduleWrapper and configd accessible from
        ## services/configuration.nix
        pkgs = pkgs // { inherit moduleWrapper configd; };
      };
    in services // {
      inherit packet-broker configd release-manager moduleWrapper;
      inherit (versionFiles) version version-id;

      ## We want to have bfshell in the profile's bin directory. To
      ## achieve that, it should be enough to inherit bf-utils here.
      ## However, bf-utils is a multi-output package and nix-env
      ## unconditonally realizes all outputs when it should just use
      ## meta.outputsToInstall. In this case, the second output is
      ## "dev", which requires the full SDE to be available. This will
      ## fail in a runtime-only binary deployment.  We work around this
      ## by wrapping bf-utils in an environment.
      bf-utils-env = pkgs.buildEnv {
        name = "bf-utils-env";
        paths = [ bf-sde.pkgs.bf-utils ];
      };
    };
  releases = builtins.map release (builtins.attrValues bf-sde.pkgs.kernel-modules);

  ## The closure of the set of all releases.  This is the set of paths
  ## that needs to be available on a binary cache for pure binary
  ## deployments.  To satisfy restrictions imposed by Intel on the
  ## distribution of parts of the SDE as a runtime system, we set up a
  ## post-build hook on the Hydra CI system to copy these paths to a
  ## separate binary cache which can be made available to third
  ## parties.  The post-build hook is triggered by the name
  ## of the derivation.
  releasesClosure = (pkgs.closureInfo {
    rootPaths = builtins.foldl' (final: next: final ++ (builtins.attrValues next)) [] releases;
  }).overrideAttrs (_: { name = "packet-broker-releases-closure"; });

  mkOnieInstaller = pkgs.callPackage (pkgs.fetchgit {
    url = "https://github.com/alexandergall/onie-debian-nix-installer";
    rev = "b866dde";
    sha256 = "09x3qiaimmd9pkwrixx62fbajxqds9m2jl5mcvrr7cnvc35gh8mc";
  }) {};
  onieInstaller = mkOnieInstaller {
    inherit nixProfile version;
    component = "packet-broker";
    ## The kernel selected here must match the kernel provided by the
    ## bootstrap profile.
    rootPaths = builtins.attrValues (release bf-sde.pkgs.kernel-modules.Debian10_9);
    binaryCaches = [ {
      url = "http://p4.cache.nix.net.switch.ch";
      key = "p4.cache.nix.net.switch.ch:cR3VMGz/gdZIdBIaUuh42clnVi5OS1McaiJwFTn5X5g=";
    } ];
    bootstrapProfile = ./installers/onie/profile;
    fileTree = ./installers/onie/files;
    activationCmd = "${nixProfile}/bin/release-manager --activate-current";
  };
  releaseInstaller = pkgs.callPackage ./installers/release-installer.nix {
    inherit releases versionFiles nixProfile;
  };

in {
  inherit releases releasesClosure onieInstaller releaseInstaller;

  ## Final installation on the target system with
  ##   nix-env -f . -p <some-profile-name> -r -i -A install
  install = release bf-sde.modulesForLocalKernel;
}
