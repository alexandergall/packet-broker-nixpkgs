{ fetchFromGitHub, perlPackages, net-snmp }:

## nix-prefetch-url --unpack --name Snabb-SNMP-0.01 \
##   https://github.com/alexandergall/snabb-snmp-subagent/archive/${rev}.tar.gz
perlPackages.buildPerlPackage  rec {
  pname = "Snabb-SNMP";
  version = "0.01";
  src = fetchFromGitHub {
    owner = "alexandergall";
    repo = "snabb-snmp-subagent";
    rev = "v5";
    sha256 = "17jcnhgi8nxvszgkkwsblrpqjccq6n0ibszh1wdwv78i3hgsirzn";
  };
  preConfigure = ''cd subagent'';
  propagatedBuildInputs = [ net-snmp ] ++
    (with perlPackages; [ NetSNMP SysMmap ]);
}
