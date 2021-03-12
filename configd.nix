{ bf-sde, src }:

let
  bf-drivers-runtime = bf-sde.pkgs.bf-drivers-runtime;
  python = bf-drivers-runtime.pythonModule;
in python.pkgs.buildPythonApplication {
  pname = "packet-broker-configd";
  version = "0.1";

  inherit src;
  propagatedBuildInputs = [
    bf-drivers-runtime
  ] ++ (with python.pkgs; [ jsonschema ipaddress ]);

  preConfigure = ''cd control-plane'';

  postInstall = ''
    mkdir -p $out/etc/packet-broker
    cp config.json schema.json $out/etc/packet-broker
  '';
}
