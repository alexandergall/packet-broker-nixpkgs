{ src ? { gitTag = "WIP"; }, buildInstaller ? false,
  buildRelease ? true, onieUsers ? {}, componentSuffix ? "" }:

with import ./. {
  inherit (src) gitTag;
  inherit onieUsers componentSuffix;
};

## The releases and releasesClosure derivations have the same
## closure. releasesClosure is used by the Hydra post-build hook
## to copy the closure to a separate binary cache.
(if buildRelease then
  {
    inherit release releaseClosure;
  }
else
  {}) //
(if buildInstaller then
  { inherit standaloneInstaller; }
  // (if builtins.match "release-[^-]+" src.gitTag != null then
       ## Build the ONIE installer for principal releases only
       { inherit onieInstaller; }
      else
        {})
else
  {})
