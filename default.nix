## When called from Hydra via release.nix or from "release-manager
## --install-git", we get the result of "git describe" passed in as
## gitTag.
{ gitTag ? "WIP", kernelRelease ? null, platform ? null, onieUsers ? {},
  componentSuffix ? "" }:

let
  pkgs = import (fetchTarball {
    ## Branch open-p4studio
    url = https://github.com/alexandergall/bf-sde-nixpkgs/archive/d3ff68e.tar.gz;
    sha256 = "1zyi8dlfbqn1ggyvlcr3bkqlcgv1zqg8kj6lhd7s73fd3paz0f4w";
  }) {
    overlays = import ./overlay;
    withAsic = true;
  };

  ## Release version of the packet broker service.  The commit for the
  ## release is tagged with "release-<version>". See
  ## README.md#versioning for the full Git workflow.
  version = "8";
  versionFile = pkgs.writeTextDir "version" "${version}:${gitTag}\n";
  nixProfile = "/nix/var/nix/profiles/packet-broker";

  ## Build the main components with the latest SDE version
  bf-sde = pkgs.bf-sde.v9_13_4;
  support = bf-sde.support;
  src = pkgs.fetchFromGitHub {
    owner = "alexandergall";
    repo = "packet-broker";
    rev = "d35769e";
    sha256 = "sha256-aQjueGaiRH/17xNC9Auou1jIqS11evza2C80cLcq8+Y=";
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
      paths = [ bf-sde.pkgs.target-utils ];
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
        inherit pkgs moduleWrapper;
        inherit (sliceCommon) configd;
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
    "accton_as9516_32d"
    "netberg_aurora_710"
    "stordis_bf6064x_t"
    "stordis_bf2556x_1t"
    "inventec_d10064"
    "asterfusion_x308p"
    "asterfusion_x312p"
    "asterfusion_x532p"
    "asterfusion_x564p"
    "asterfusion_x732q_t"
    "model"
    "modelT2"
  ];
  release = support.mkRelease slice bf-sde.pkgs.kernel-modules platforms;
  releaseClosure = support.mkReleaseClosure release "packet-broker";
  component = "packet-broker" + componentSuffix;
  onieInstaller = (support.mkOnieInstaller {
    inherit version nixProfile slice component;
    platforms = builtins.filter (p: builtins.match "^model.*" p == null) platforms;
    bootstrapProfile = ./onie/profile;
    fileTree = ./onie/files;
    NOS = "NOS";
    binaryCaches = [ {
      url = "http://p4.cache.nix.net.switch.ch";
      key = "p4.cache.nix.net.switch.ch:cR3VMGz/gdZIdBIaUuh42clnVi5OS1McaiJwFTn5X5g=";
    } ];
    users = onieUsers;
  }).override { memSize = 6*1024; };
  standaloneInstaller = support.mkStandaloneInstaller {
    inherit release version gitTag nixProfile component;
  };

in {
  inherit release releaseClosure onieInstaller standaloneInstaller;
  ## For the "install" make target
  inherit (sliceCommon) release-manager;

  ## Final installation on the target system with
  ##   nix-env -f . -p <some-profile-name> -r -i -A install --argstr kernelRelease $(uname -r) --argstr platform <platform>
  install =
    assert kernelRelease != null && platform != null;
    assert pkgs.lib.assertMsg (builtins.elem platform platforms) "Unsupported platform: ${platform}";
    slice (bf-sde.modulesForKernel kernelRelease) platform;
}
