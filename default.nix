## When called from Hydra via release.nix or from "release-manager
## --install-git", we get the result of "git describe" passed in as
## gitTag.
{ gitTag ? "WIP", kernelRelease ? null }:

let
  pkgs = import (fetchTarball {
    url = https://github.com/alexandergall/bf-sde-nixpkgs/archive/v4.tar.gz;
    sha256 = "0rq29pzr2brjxam78pcdrkcn856x5yf2p60vgf7ig0yf9k7z6gzm";
  }) {
    overlays = import ./overlay;
  };

  ## Release version of the packet broker service.  The commit for the
  ## release is tagged with "release-<version>". The version should be
  ## bumped to the next planned release right after tagging.
  ##
  version = "1";
  versionFile = pkgs.writeTextDir "version" "${version}:${gitTag}\n";
  nixProfile = "/nix/var/nix/profiles/per-user/root/packet-broker";

  ## Build the main components with the latest SDE version
  bf-sde = pkgs.bf-sde.latest;
  src = pkgs.fetchFromGitHub {
    owner = "alexandergall";
    repo = "packet-broker";
    rev = "v1";
    sha256 = "1rfm286mxkws8ra92xy4jwplmqq825xf3fhwary3lgvbb59zayr9";
  };

  ## A slice is the subset of a release that only contains the
  ## modules and wrapper for a single kernel.  At install time on a
  ## particular system, the installer selects the slice that matches
  ## the system's kernel. A slice is identified by the kernelID of the
  ## selected modules package. The kernel release identifier is
  ## included as well to let the release-manager provide more useful
  ## output.
  slice = kernelModules:
    let
      sliceFile = pkgs.writeTextDir "slice"
        "${kernelModules.kernelID}:${kernelModules.kernelRelease}\n";
      packet-broker = pkgs.callPackage ./packet-broker.nix {
        inherit bf-sde src version;};
      configd = pkgs.callPackage ./configd.nix {
        inherit bf-sde src version;
      };
      release-manager = pkgs.callPackage ./release-manager {
        inherit version;
      };
      moduleWrapper = packet-broker.moduleWrapper' kernelModules;
      services = import ./services {
        ## Make moduleWrapper and configd accessible from
        ## services/configuration.nix
        pkgs = pkgs // { inherit moduleWrapper configd; };
      };
    in services // {
      inherit versionFile sliceFile packet-broker configd release-manager moduleWrapper;
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
  ## A release is the union of the slices for all supported kernels
  release = builtins.mapAttrs (_: modules: slice modules) bf-sde.pkgs.kernel-modules;

  ## The closure of the set of all releases.  This is the list of
  ## paths that needs to be available on a binary cache for pure
  ## binary deployments.  To satisfy restrictions imposed by Intel on
  ## the distribution of parts of the SDE as a runtime system, we set
  ## up a post-build hook on the Hydra CI system to copy these paths
  ## to a separate binary cache which can be made available to third
  ## parties.  The post-build hook is triggered by the name of the
  ## derivation, hence the override.
  releaseClosure = (pkgs.closureInfo {
    rootPaths = builtins.foldl'
                  (final: next: final ++ (builtins.attrValues next)) []
                  (builtins.attrValues release);
  }).overrideAttrs (_: { name = "packet-broker-release-closure"; });

  mkOnieInstaller = pkgs.callPackage (pkgs.fetchgit {
    url = "https://github.com/alexandergall/onie-debian-nix-installer";
    rev = "2adc7d6";
    sha256 = "0l95r97knig3pyk0zmbijpk5lih30hn3azmngk2rdjm7ag9vm12p";
  }) {};
  onieInstaller = mkOnieInstaller {
    inherit nixProfile version;
    component = "packet-broker";
    ## The kernel selected here must match the kernel provided by the
    ## bootstrap profile.
    rootPaths = builtins.attrValues (slice bf-sde.pkgs.kernel-modules.Debian10_9);
    binaryCaches = [ {
      url = "http://p4.cache.nix.net.switch.ch";
      key = "p4.cache.nix.net.switch.ch:cR3VMGz/gdZIdBIaUuh42clnVi5OS1McaiJwFTn5X5g=";
    } ];
    bootstrapProfile = ./installers/onie/profile;
    fileTree = ./installers/onie/files;
    activationCmd = "${nixProfile}/bin/release-manager --activate-current";
  };
  releaseInstaller = pkgs.callPackage ./installers/release-installer.nix {
    inherit release version gitTag nixProfile;
  };

in {
  inherit release releaseClosure onieInstaller releaseInstaller;

  ## Final installation on the target system with
  ##   nix-env -f . -p <some-profile-name> -r -i -A install --argstr kernelRelease $(uname -r)
  install =
    if kernelRelease != null then
      slice (bf-sde.modulesForKernel kernelRelease)
    else
      throw "Missing required argument kernelRelease";
}
