{ src }:

with import ./. { inherit (src) gitTag; };

## Have the CI build the data-plane and control-plane programs as well
## as the closure for binary deployments.
{
  inherit release closure;
} //
## Build the ONIE installer only for releases
(if (builtins.match "release-[0-9]+" src.gitTag != null) then
  { inherit onieInstaller; }
else
  {})
