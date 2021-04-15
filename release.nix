{ src ? { gitTag = "WIP"; }, buildInstaller ? false }:

with import ./. { inherit (src) gitTag; };

## The releases and releasesClosure derivations have the same
## closure. releasesClosure is used by the Hydra post-build hook
## to copy the closure to a separate binary cache.
{
  inherit release releaseClosure;
} //
(if buildInstaller then
  { inherit releaseInstaller; }
  // (if builtins.match "release-[^-]+" src.gitTag != null then
       ## Build the ONIE installer for principal releases only
       { inherit onieInstaller; }
      else
        {})
else
  {})
