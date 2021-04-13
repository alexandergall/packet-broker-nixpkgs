{ release, version, gitTag, nixProfile, lib, runCommand, closureInfo,
  coreutils, gnutar, gnused, rsync }:

let
  sliceInfo = slice:
    let
      rootPaths = builtins.attrValues slice;
      closure = closureInfo { inherit rootPaths; };
      modules = slice.moduleWrapper.modules;
    in builtins.concatStringsSep ":" (
       with modules; [ kernelID kernelRelease closure ]
       ++ rootPaths);
  sliceInfos = builtins.map sliceInfo (builtins.attrValues release);
in runCommand "packet-broker-release-installer" {
  inherit sliceInfos;
} ''
  mkdir tmp
  cd tmp
  storePaths=
  for info in $sliceInfos; do
    read kernelID kernelRelease closureInfo rootPaths < <(echo $info | tr ':' ' ')
    dest=$kernelRelease/$kernelID
    mkdir -p $dest
    cp $closureInfo/{registration,store-paths} $dest
    storePaths="$storePaths $closureInfo/store-paths"
    echo "$rootPaths" >$dest/rootPaths
  done

  tar cf store-paths.tar $(cat $storePaths | sort | uniq | tr '\n' ' ')
  echo "${version}:${gitTag}" >version
  echo ${nixProfile} >profile
  cp ${./install.sh} install.sh
  chmod a+x install.sh
  patchShebangs install.sh
  substituteInPlace install.sh --subst-var-by PATH \
    "${lib.strings.makeBinPath [ coreutils gnutar gnused rsync ]}"

  tar cf ../archive.tar *
  cd ..
  xz -T0 archive.tar

  mkdir $out
  cat ${./self-extractor.sh} archive.tar.xz >$out/installer.sh
  chmod a+x $out/installer.sh
  patchShebangs $out/installer.sh
  echo ${version} >$out/version
''
