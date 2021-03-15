let
  ## Pull in nixpkgs containing the SDE as our nixpkgs repository
  bf-sde-nixpkgs-url = https://github.com/alexandergall/bf-sde-nixpkgs/archive/1576f8ba68a5af090f9b0667d877a7916b75aea9.tar.gz;
  pkgs = import (fetchTarball bf-sde-nixpkgs-url) {
    overlays = import ./overlay ++ [
      ## For services/configuration.nix
      (self: super: {
        packet-broker = { inherit moduleWrapper configd; };
    }) ];
  };

  ## Build the main components with the latest SDE version
  bf-sde = pkgs.bf-sde.latest;
  src = pkgs.fetchFromGitHub {
    owner = "alexandergall";
    repo = "packet-broker";
    rev = "366999";
    sha256 = "1rfm286mxkws8ra92xy4jwplmqq825xf3fhwary3lgvbb59zayr9";
  };
  packet-broker = pkgs.callPackage ./packet-broker.nix { inherit bf-sde src; };
  configd = pkgs.callPackage ./configd.nix { inherit bf-sde src; };
  release = { inherit packet-broker configd; };

  ## These derivations have to be built on the final install target
  moduleWrapper = packet-broker.makeModuleWrapper;
  services = import ./services { inherit pkgs; };

  ## Closure for binary deployments containing the release derivations
  ## plus the modules for all supported kernels and the SNMP agent.
  ## If this closure is available in the Nix store of the target or
  ## through a binary cache, only the services and wrapper will be
  ## built locally. Note that bf-utils is part of the closure of
  ## release.packet-broker so we don't have to include it explicitly.
  closure = pkgs.buildEnv {
    name = "packet-broker-closure";
    paths = builtins.attrValues (release // bf-sde.buildModulesForAllKernels //
                                 { inherit (pkgs) SNMPAgent; });

    ## Ignore collisions of the module install scripts. The
    ## environment is just a vehicle to collect everything in a single
    ## derivation.
    ignoreCollisions = true;
  };

  ## We want to have bfshell in the profile's bin directory. To
  ## achieve that, it should be enough to inherit bf-utils in the
  ## "install" attribute set below here. However, bf-utils is a
  ## multi-output package and nix-env unconditonally realizes all
  ## outputs when it should just use meta.outputsToInstall. In this
  ## case, the second output is "dev", which requires the full SDE to
  ## be available. This will fail in a runtime-only binary deployment.
  ## We work around this by wrapping bf-utils in an environment.
  bf-utils-env = pkgs.buildEnv {
    name = "bf-utils-env";
    paths = [ bf-sde.pkgs.bf-utils ];
  };

in {
  ## For release.nix
  inherit release closure;

  ## Final installation on the target system with
  ##   nix-env -f . -p <some-profile-name> -r -i -A install
  install = release // services // {
    inherit moduleWrapper bf-utils-env;
  };
}
