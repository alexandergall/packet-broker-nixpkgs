## When called from Hydra via release.nix or from "release-manager
## --install-git", we get the result of "git describe" passed in as
## gitTag.
{ gitTag ? "WIP", kernelRelease ? null, platform ? null, onieUsers ? {},
  componentSuffix ? "" }:

let
  pkgs = import (fetchTarball {
    url = https://github.com/alexandergall/bf-sde-nixpkgs/archive/v11.tar.gz;
    sha256 = "01i37jz7ds4mb9xw0xlwc20riby6ys4f03xgn6sh8a5mb2416rn5";
  }) {
    overlays = import ./overlay;
  };

  ## Release version of the packet broker service.  The commit for the
  ## release is tagged with "release-<version>". See
  ## README.md#versioning for the full Git workflow.
  version = "4";
  versionFile = pkgs.writeTextDir "version" "${version}:${gitTag}\n";
  nixProfile = "/nix/var/nix/profiles/packet-broker";

  ## Build the main components with the latest SDE version
  bf-sde = pkgs.bf-sde.latest;
  support = bf-sde.support;
  src = pkgs.fetchFromGitHub {
    owner = "alexandergall";
    repo = "packet-broker";
    rev = "v1";
    sha256 = "1rfm286mxkws8ra92xy4jwplmqq825xf3fhwary3lgvbb59zayr9";
  };
  sliceCommon = {
    inherit versionFile;
    configd = pkgs.callPackage ./configd.nix {
      inherit bf-sde src version;
    };
    release-manager = support.mkReleaseManager {
      inherit version nixProfile;
      apiType = "github";
      repoUrl = "https://github.com//alexandergall/packet-broker-nixpkgs";
      apiUrl = "https://api.github.com/repos/alexandergall/packet-broker-nixpkgs";
      activationCode = ./release-manager/activation.sh;
      installCmds = ''
        mkdir -p $out/etc/snmp $out/var/lib/snmp
        cp ${./release-manager/snmpd.conf} $out/etc/snmp/snmpd.conf
        cp ${./release-manager/ifindex} $out/etc/snmp/ifindex
        cp ${./release-manager/interface.conf} $out/var/lib/snmp/interface.conf
      '';
    };
    ## nix-env does not handle multi-output derivations correctly. We
    ## work around this by wrapping those derivations in an
    ## environment.
    auxEnv = pkgs.buildEnv {
      name = "aux-env";
      paths = [ bf-sde.pkgs.bf-utils ];
    };
  };

  ## A slice is the subset of a release that only contains the modules
  ## and wrapper for a single kernel and a particular platform.  At
  ## install time, the installer selects the slice that matches the
  ## system's kernel and platform.
  slice = kernelModules: platform:
    let
      sliceFile = pkgs.writeTextDir "slice"
        "${kernelModules.kernelID}:${kernelModules.kernelRelease}:${platform}\n";
      packet-broker = pkgs.callPackage ./packet-broker.nix {
        inherit bf-sde src version platform;
      };
      moduleWrapper = packet-broker.moduleWrapper' kernelModules;
      services = import ./services {
        ## Make moduleWrapper and configd accessible from
        ## services/configuration.nix
        pkgs = pkgs // {
          inherit moduleWrapper;
          inherit (sliceCommon) configd;
        };
      };
    in sliceCommon // services // {
      inherit sliceFile packet-broker moduleWrapper;
    };
  ## A release is the union of the slices for all supported kernels
  ## and platforms
  platforms = [
    "accton_wedge100bf_32x"
    "accton_wedge100bf_32qs"
    "accton_wedge100bf_65x"
    "inventec_d5264q28b"
  ];
  release = support.mkRelease slice bf-sde.pkgs.kernel-modules platforms;
  releaseClosure = support.mkReleaseClosure release "packet-broker";
  component = "packet-broker" + componentSuffix;
  onieInstaller = support.mkOnieInstaller {
    inherit version nixProfile platforms component;
    ## The kernel used here must match that from the profile
    partialSlice = slice bf-sde.pkgs.kernel-modules.Debian10_9;
    bootstrapProfile = ./onie/profile;
    fileTree = ./onie/files;
    NOS = "NOS";
    binaryCaches = [ {
      url = "http://p4.cache.nix.net.switch.ch";
      key = "p4.cache.nix.net.switch.ch:cR3VMGz/gdZIdBIaUuh42clnVi5OS1McaiJwFTn5X5g=";
    } ];
    users = onieUsers;
  };
  standaloneInstaller = support.mkStandaloneInstaller {
    inherit release version gitTag nixProfile component;
  };

in {
  inherit release releaseClosure onieInstaller standaloneInstaller;

  ## Final installation on the target system with
  ##   nix-env -f . -p <some-profile-name> -r -i -A install --argstr kernelRelease $(uname -r) --argstr platform <platform>
  install =
    assert kernelRelease != null && platform != null;
    slice (bf-sde.modulesForKernel kernelRelease) platform;
}
