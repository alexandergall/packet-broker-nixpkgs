{ bf-sde, src }:

bf-sde.buildP4Program rec {
  version = "0.1";
  pname = "packet-broker";
  p4Name = "packet_broker";
  inherit src;
  requiredKernelModule = "bf_kpkt";
}
