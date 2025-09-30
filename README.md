# packet-broker-nixpkgs

Packaging of the [P4 Packet
Broker](https://github.com/alexandergall/packet-broker) for the Nix
package manager.

Contents

   * [Overview](#overview)
   * [Supported Platforms](#supportedPlatforms)
   * [Downloads](#downloads)
   * [Initial Setup using the Pre-Built ONIE Installer](#ONIE)
   * [Configuration and Usage](#configurationUsage)
      * [`systemd` services](#systemdServices)
	  * [Packet Broker Configuration](#packetBrokerConfiguration)
	  * [`bf_switchd` CLI](#bfSwitchdCLI)
   * [Release Management](#releaseManagement)
      * [Versioning](#versioning)
	  * [Release Contents](#releaseContents)
	  * [Kernel and Platform Support](#kernelPlatformSupport)
	  * [Using the Release Manager](#usingReleaseManager)
	  * [Standalone Release Installer](#standaloneInstaller)
   * [Building](#building)
      * [From Scratch](#buildingScratch)
	  * [Installers from pre-Built Packages](#buildingPreBuilt)

## <a name="overview"></a>Overview

The set of packages produced by this Nix expression (`default.nix`)
provides a complete deployment of the Packet Broker as an appliance on
systems based on the Tofino packet-processing ASIC.  It includes an
ONIE installer for the initial setup and a tool for managing releases
on a running system.

Currently, the base OS provided by the ONIE installer is a basic
version of Debian 13.1 combined with an installation of the [Nix
package manager](https://nixos.org/manual/nixpkgs/stable/).  While
Debian is used to manage the host itself, all components of the Packet
Broker service are provided by Nix. This repository depends on the
[Nix packaging of the Tofino
SDE](https://github.com/alexandergall/bf-sde-nixpkgs) and the [ONIE
installer
builder](https://github.com/alexandergall/onie-debian-nix-installer).

The original SDE was closed source and required an NDA from Intel to
access.  Most of the SDE has now been open-sourced as
[open-p4studio](https://github.com/p4lang/open-p4studio) by the p4lang
consortium. Unfortunatley, that version is limited to the Tofino
software emulation and to get full ASIC support still requires access
to the original SDE. Nix packaging for this hybrid version is
currently provided on a [separate branch of the bf-sde-nixpkgs
repository(https://github.com/alexandergall/bf-sde-nixpkgs/tree/open-p4studio).

The main advantages of using this framework are

   * Declarative style of package management: all properties and
     dependencies of software components are declared explicitly in a
     high-level description of the desired system
   * Precise dependency tracking: dependencies include all properties
     of the dependent package, not just its name and version
   * High level of reproducibility: given the declarative description
     of the system, anyone can reproduce the packages exactly
     (e.g. without any dependencies on the environment of the
     build host)
   * Isolation from the package manager of the base OS: [except for
     the kernel](#kernelPlatformSupport), the Nix packages are completely
     self-contained and do not depend on any packages of the host's
     native package manager

As a result, the system provides for very reliable deployments of the
service, avoiding many potential problems that are inherent with
traditional package managers.

The built-in release manager performs all interactions with the Nix
package manager on behalf of the user.  While no knowledge of Nix is
required to work with the system, the curious user is encouraged to
learn about this great tool as the key to reliable service deployment
:)

In principle, it is very easy to [build any of the components
yourself](#building). In fact, having everything defined in terms of
Nix expressions makes it not only easy but also reproducible on any
Linux-based system irrespective of the distribution being used. The
only prerequisite is the presence of the Nix package manager itself.

However, building everything from scratch requires access to the
Tofino SDE, which is currently only possible by entering an NDA with
Intel.  But Intel also grants the right to distribute certain parts of
the SDE as pre-built packages for binary deployments. For the Packet
Broker project, those packages are publicly available from a
repository hosted at `p4.cache.nix.net.switch.ch`. The [ONIE
installer](#ONIE) comes with this repository pre-configured.

## <a name="supportedPlatforms"></a>Supported Platforms

The packages only support Tofino ASICs of the first generation at this
time.  The Packet Broker packages support the following platforms

   * `accton_wedge100bf_32x`
   * `accton_wedge100bf_32qs`
   * `accton_wedge100bf_65x`
   * `accton_as9516_32d`
   * `netberg_aurora_710`
   * `stordis_bf6064x_t` (BSP-less mode)
   * `stordis_bf2556x_1t` (BSP-less mode)
   * `inventec_d10064` (BSP-less mode)
   * `asterfusion_x308p`
   * `asterfusion_x312p`
   * `asterfusion_x532p`
   * `asterfusion_x564p`
   * `asterfusion_x732q_t`
   * `model`
   * `modelT2`

The `as9516` and `X732Q-T` are based on Tofino2, all other platforms
are based on Tofino1. The `model` and `modelT2` are pseudo platforms
that use the software emulation of the Tofino1 and Tofino2,
respectively. They can be instantiated on systems that don't have an
actual ASIC for testing purposes.

The platforms marked with "BSP-less mode" don't provide a "baseboard
support package" for the current SDE version. This means that the
system cannot interact with the QSFP ports, e.g. to query various
properties of inserted plugins like the plugin type or optical power
levels.

## <a name="downloads"></a>Downloads

Installers for the releases of the Packet Broker are [available for
download](http://hydra.nix.net.switch.ch/packet-broker/releases/). For
each release, there is a ONIE-based installer for the initial version
of the release named `onie-installer.bin` and one [standalone
installer](#standaloneInstaller) for every update. No installers are
provided for development versions. Those pre-releases can be installed
with the [`release-manager`'s](#usingReleaseManager) `--install-git`
option.

## <a name="ONIE"></a>Initial Setup using the Pre-Built ONIE Installer

Devices like the `accton_wedge100bf_32x` usually come with a
pre-installed ONIE.  ONIE-compatible installers for releases of the
Packet Broker are [available for
download](http://hydra.nix.net.switch.ch/packet-broker/releases/). To
perform an installation, boot the system into "ONIE install
mode". Then copy the URL of the `onie-installer.bin` file for the
desired release and execute `onie-nos-install <URL>` at the `ONIE`
prompt. For example

```
ONIE# onie-nos-install http://hydra.nix.net.switch.ch/packet-broker/releases/1/onie-installer.bin
```

Note well: **This procedure destroys all partitions beyond partitions
1 and 2**. The EFI and ONIE partitions are preserved and the GRUB boot
loader of the Debian system (installed in partition 3) includes an
entry to chain-load the ONIE boot loader to make it easy to perform
ONIE operations after an image has been installed.

If the device does not belong to the [list of supported
platforms](#supportedPlatforms), the installer will emit a message of
the form

```
Unsupported platform: <ONIE platform identifier>
```

The installation will still proceed but the packet broker application
will not be available.

## <a name="configurationUsage"></a>Configuration and Usage

After the initial setup, the system has the following properties

   * No regular user account
   * Root access without password on the serial console only
   * The management interface is set up to perform DHCP
   * An empty Packet Broker configuration in
     `/etc/packet-broker/config.json`
   * A basic `snmpd` configuration in `/etc/snmp/snmpd.conf`, which
     does not allow any non-local connections
   * Pre-built Nix packages are fetched from
     http://p4.cache.nix.net.switch.ch/ (via `/etc/nix/nix.conf`)

The OS can be freely configured as a regular Debian system. Changes to
the Debian packages will not impact the Packet Broker service in any
way, except for a change of kernel.

### <a name="systemdServices"></a>`systemd` services

The Packet Broker implements the following `systemd` services.

#### `packet-broker.service`

This is the main service unit, which runs the `bf_switchd` daemon to
execute the P4 program.

#### `packet-broker-configd.service`

This service units runs the control-plane process `configd` as a
daemon. It is automatically started and stopped with the main
`packet-broker.service`.

#### `snmpd.service`

This service runs an instance of the `net-snmp` SNMP daemon. It uses
the AgentX protocol to communicate with `snabb-snmp-agent.service`,
which provides the MIB for the interfaces controlled by the packet
broker.

#### `snabb-snmp-agent.service`

To make interface counters available via SNMP, the services `snmpd`
and `snabb-snmp-agent` must also be enabled (which is the default).
This also requires the configuration of access rules (SNMP community
strings and access-lists) in `/etc/snmp/snmpd.conf`. The service is
automatically started and stopped with the `snmpd` service.

### <a name="packetBrokerConfiguration"></a>Packet Broker Configuration

To configure the Packet Broker, edit `/etc/packet-broker/config.json`
and execute either

```
$ brokerctl reload
```

or

```
# systemctl reload packet-broker-configd
```

For a complete description of the available options for `config.json`
and the `brokerctl` command please refer to the [Packet Broker
documentation](https://github.com/alexandergall/packet-broker/blob/master/README.md)

### <a name="bfSwitchdCLI"></a>`bf_switchd` CLI

Use the `bfshell` command to enter the CLI provided by the
`bf_switchd` daemon.  Please refer to the documentation provided by
Intel on how to use the CLI.

## <a name="releaseManagement"></a>Release Management

The maintenance of releases of the Packet Broker service is performed
with a separate utility called `release-manager`, which is part of the
release itself.

Any number of releases can be installed on the system
concurrently. Only one of the releases is active at any given time and
it is possible to switch between any of the installed releases
arbitrarily. The following section describes how versioning of
releases is defined for the Packet Broker project.

### <a name="versioning"></a>Versioning

The repository uses the `master` branch for development of the
upcoming release. The actual version number is defined as the
`version` attribute in `default.nix`. Currently, the version is chosen
to be an integer without any additional structure.  However, the only
assumption made by the `release-manager` is that it is unique for each
release and doesn't contain any hyphens.

At the time of release of version `<v>` (the current value of the
`version` attribute), the maintainer performs the following tasks

   * Tag the commit on the `master` branch
      ```
      git tag -a -m "Release <v>" release-<v>
      git push origin release-<v>
      ```
   * Create a release branch with the version `<v>` as name
      ```
      git checkout -b <v>
      git push origin <v>
      ```
   * On `master`
      * Add a Hydra CI job for `release-<v>` to `spec.json`
      * bump the version in `default.nix` to `<v+1>`
      * add `release-notes/release-<v+1>.md`
      * `git commit -m "Release <v+1> beta`
	  * `git push origin master`

Development of the next release with version `<v+1>` takes place on
`master`. Updates to release `<v>` are maintained on the branch
`<v>`. This is mainly intended for fixes of bugs and security issues.

The branch-off points carrying the Git tags `release-<v>` are called
_principal releases_.  All other commits are either updates of a
principal release (if they are on a release branch) or pre-releases of
the next version (if they are on `master`).

The `git describe` mechanism is used to uniquely identify all commits
in relation to the principal release from which they are derived.  We
refer to this identifier as `gitTag` throughout this documentation and
in the `release-manager` utility.  The `gitTag` expresses the
"distance" of the commit to the closest annotated tag reachable from
the commit in the form `<tag>-<n>-g<commit>`, where `<tag>` is the
name of the annotated tag, `<n>` is the number of commits following
the tagged commit and `<commit>` is the abbreviated commit itself.

By convention, `<tag>` is always of the form `release-<v>` in this
repository. With this, every commit belongs to one of two classes:

   1. `<gitTag>` is of the form `release-<v>`. This marks the principal
      release of version `<v>`.
   2. `<gitTag>` is of the form `release-<v>-<n>-g<abbrev>`. This
      identifies the release as an update of the principal release
      `<v>` or a pre-release of the next release.

If we also take the value of the `version` attribute into account, the
commits in the second class can be further distinguished:

   * `<v>` is equal to `version`. Such a commit is an update of a
     principal release on a release branch.
   * `<v>` is equal to `version-1`. Such a commit is a pre-release of
     release `version` on the `master` branch.

### <a name="releaseContents"></a>Release Contents

A release of the Packet Broker service is comprised of the following
components

   * `packet-broker`. A command which starts the `bf_switchd` process
     provided by the Tofino SDE with the compiled [`packet-broker` P4
     program](https://github.com/alexandergall/packet-broker/blob/master/packet_broker.p4).
   * `packet-broker-module-wrapper`. A wrapper script around
     `packet-broker`, which loads the appropriate kernel module before
     starting `bf_switchd`.
   * `configd`. A command that starts the
     [control-plane](https://github.com/alexandergall/packet-broker/tree/master/control-plane)
     process, which reads the configuration file and programs the
     match-action-units on the ASIC accordingly. It also communicates
     with the `brokerctl` CLI utility.
   * `systemd` service units. A set of unit files for the
     `packet-broker`, `packet-broker-configd`, `snmpd` and
     `snabb-snmp-agent` services.
   * `bf-utils`. A package provided by the SDE which includes the
     `bfshell` command used to start a CLI session with the running
     `bf_switchd` process.
   * `release-manager`. A command to manage releases of the service.
   * `version`. A file containing the version information of the
     release.
   * `slice`. A file containing information about which
     [slice](#slice) of the release is installed on the system.

Each of these components is a package by itself in the sense of the
Nix package manager.  In other words, the release is a collection of
packages which is treated as a unit by the release manager (through a
feature of Nix called a _profile_).

The `version` file contains the version and gitTag as a string of the
form `<version>:<gitTag>`.

The `slice` file contains the kernel ID, kernel release and platform
identifiers as a string of the form
`<kernelID>:<kernelRelease>:<platform>`.

### <a name="kernelPlatformSupport"></a>Kernel and Platform Support

The `bf_switchd` process has two dependencies on the environment in
which it is running.  The first is the dependence on the
_baseboard_. Every platform uses the Tofino ASIC in a specific
hardware configuration. In general, these configurations differ in how
they integrate the ASIC with external components like QSFP connectors
or gear boxes.  These configurations are called baseboards.  The
baseboard-specific code is hidden behind a generic API and confined to
a small set of shared objects that provide implementations of the API
for each baseboard.  The`bf_switchd` binary must be configured to load
the shared object appropriate for the baseboard on which it runs.  The
SDE contains support for a specific set of baseboards. A baseboard can
support multiple platforms. For example, all platforms of the `accton`
family use the same baseboard (i.e. the mapping of platforms to
baseboards is unique but not the other way round).

The second dependency is the kernel module required by `bf_switchd`.
The SDE includes a set of kernel modules needed by the `bf_switchd`
process.  Every kernel for which these modules should be built must be
explicitly supported by the SDE package. The [list of supported
kernels](https://github.com/alexandergall/bf-sde-nixpkgs/blob/master/bf-sde/kernels/default.nix)
is part of the SDE package definition.

A release of the Packet Broker includes the modules for all supported
kernels on all supported platforms.  At the time of installation on a
specific target, only the components that match the target's platform
and kernel will be installed.  This implies that a release cannot be
installed on an unsupported kernel or an unsupported platform.

<a name="slice"/>
This subset of a release is referred to as a _slice_.  By definition,
all slices have the same version information. Since it is possible to
install multiple slices on a system to support kernel upgrades or
multi-kernel configurations, it is necessary to distinguish them from
each other. For this purpose, each slice includes a file called
`slice`, containing the identifier of the kernel and platform in the
form `<kernelID>:<kernelRelease>:<platform>`.

The `<kernelID>` is already a unique identifier for the
kernel. Technically, it is the name of the attribute in a set that
defines the [properties of every supported
kernel](https://github.com/alexandergall/bf-sde-nixpkgs/blob/master/bf-sde/kernels/default.nix)
in the `bf-sde-nixpkgs` Nix expression, e.g. `Debian11_7` or
`Debian12_1`. Each such definition includes the exact kernel release
identifier of that kernel, which is the result of running `uname -r`
on a running instance of the kernel.

The kernel release string is included in the slice identifier as the
`<kernelRelease>` string.  The sole purpose of this is to make it
explicit to the administrator for which kernel a release has been
built when looking at an installed instance. For example, the
following one-to-one correspondence holds for the kernels with
`kernelID` `Debian10_8` and `Debian10_9`

   * `<kernelID>` = `Debian11_7` <=> `<kernelRelease>` = 5.10.0-22-amd64
   * `<kernelID>` = `Debian12_1` <=> `<kernelRelease>` = 6.1.0-10-amd64

The `<platform>` identifier is one of the [list of supported
platforms](#supportedPlatforms). It corresponds exactly to the value
of the `onie_machine` identifier in the file `/etc/machine.conf`. This
file is created automatically by the ONIE installer.

### <a name="usingReleaseManager"></a>Using the Release Manager

All manipulations of releases are performed with the `release-manager`
CLI tool which is part of every release.  Please refer to the
[documentation](https://github.com/alexandergall/bf-sde-nixpkgs/blob/master/bf-sde/support/README.md#releaseManager)
for the list of supported options and their usage.  The service
activation and deactivation options specific to the packet broker are
as follows.

#### `--activate-current`

Mere installation of a release does not instantiate the Packet Broker
service automatically. This only happens after _activation_.
Activation performs the following operations for the generation marked
as "current"

   * Create symbolic links to the `systemd` service units in
     `/etc/systemd/system`
   * Enable the services
      * `systemctl enable packet-broker packet-broker-configd snmp snabb-snmp-agent`
   * Call `systemctl daemon-reload`
   * Create directories (if they don't exist already)
      * `/etc/packet-broker`
      * `/etc/snmp`
      * `/var/lib/snmp`
   * Create symbolic links for the files (replacing existing ones)
      * `/etc/packet-broker/schema.json`
      * `/etc/snmp/ifindex`
      * `/var/lib/snmp/interface.conf`
   * Install defaults (does not overwrite existing files)
      * `/etc/packet-broker/config.json`
      * `/etc/snmp/snmpd.conf`
   * Create (to add the profile to `PATH`)
      * `/etc/profile.d/packet-broker.sh`
   * Start the services
      * `systemctl start packet-broker`
      * `systemctl start snmpd`

#### `--deactivate-current`

This performs the reverse of `--activate-current`

   * Stop the services
      * `systemctl stop snmpd packet-broker`
   * Disable the services
      * `systemctl disable packet-broker packet-broker-configd snmp
        snabb-snmp-agent`
   * Unload SDE kernel modules

**Implementation note**: this option essentially calls the
`nix-collect-garbage` utility, which can also be called directly by
the user.

### <a name="standaloneInstaller"></a>Standalone Release Installer

The installation functionality of the `release-manager` requires that
the device has access to the Internet to download various
components. It is fairly common that network operators have more or
less severe restrictions on the extent to which this is possible,
mostly due to security concerns but also due to technical reasons
(e.g. using non-routable addresses for the management ports).

To overcome this limitation, the Packet Broker can also be installed
through a self-contained installer, which doesn't need any network
access once it is copied to the target device.  This installer consist
of a single self-extracting archive.

**Note**: The installer also uses Nix packages to avoid dependencies
on packages of the OS as much as possible. However, it does require
the presence of the following commands for bootstrapping: `/bin/bash`
and `id`, `tail`, `xz` from `PATH`. It also assumes, of course, that
Nix is present and the Nix commands are available in
`/nix/var/nix/profiles/default/bin` (this should be the case after a
regular installation of Nix in multi-user mode).

Standalone installers for all releases can be downloaded from the
[same site as the ONIE
installer](http://hydra.nix.net.switch.ch/packet-broker/releases/). The
files are named `packet-broker-<gitTag>-install.sh` and are
accompanied by a file with the extension `.sha256` containing the
SHA256 hash for verification.  There is one standalone installer per
commit on the respective release branch.

Once the installer has been copied to the device, execute it as root,
e.g.

```
$ sudo packet-broker-release-1-install.sh
Unpacking archive
INFO: Installing packet broker release 2 (Id: 2:release-1-5-g5ab2454) for kernel 4.19.0-16-amd64 on platform accton_wedge100bf_32x in /nix/var/nix/profiles/packet-broker
INFO: Copying store paths
INFO: Registering paths in DB
INFO: Installing the service in /nix/var/nix/profiles/packet-broker
building '/nix/store/wnlw92sz2jh4rhd1mwrq687rhrq40kjv-user-environment.drv'...
created 39 symlinks in user environment
INFO: Installation completed
INFO: Use "release-manager --switch-to-generation 2" to switch to this release
Currently installed releases:
Generation Current Release Git Tag                    KernelID       Kernel Release            Platform                   Install date
-----------------------------------------------------------------------------------------------------------------------------------------------------------
         1 *       2       WIP                        Debian10_9     4.19.0-16-amd64           accton_wedge100bf_32x      2021-06-30 12:12:02.578064597 +0200
         2         2       release-1-5-g5ab2454       Debian10_9     4.19.0-16-amd64           accton_wedge100bf_32x      2021-07-01 11:27:19.801208594 +0200
```

The result is exactly the same as with the `--install-{release,git}`
options of `release-manager`, i.e. the releases installed with a
standalone installer can be manipulated with `release-manager` like
those that were installed with the native method.

## <a name="building"></a>Building

### <a name="buildingScratch"></a>From Scratch

To build everything from scratch you need access to the Tofino SDE
from Intel (currently available only by signing an NDA). You also need
an installation of the Nix package manager on any Linux distribution,
provided it supports the `x86-64` architecture.

For details how to set up your build system please refer to the first
section of the [documentation of the SDE Nix
package](https://github.com/alexandergall/bf-sde-nixpkgs/tree/open-p4studio#bf-sde-nixpkgs). You
need to perform the steps

   * [Install the Nix package manager in multi-user
     mode](https://github.com/alexandergall/bf-sde-nixpkgs/tree/open-p4studio#install-the-nix-package-manager-in-multi-user-mode)
   * [Fetch and verify source
     archives](https://github.com/alexandergall/bf-sde-nixpkgs/tree/open-p4studio#fetch-and-verify-source-archives)
   * [Add archives to the Nix
     store](https://github.com/alexandergall/bf-sde-nixpkgs/tree/open-p4studio#add-archives-to-the-nix-store)

Then clone this repository

```
$ git clone https://github.com/alexandergall/packet-broker-nixpkgs.git
```

Check out the desired release, e.g.

```
$ cd packet-broker-nixpkgs
$ git checkout release-8
```

To build the ONIE installer, execute

```
$ make onieInstaller
```

This will build everything from the SDE source code and take between
30 and 60 minutes, depending on your build host.

The result is a Nix _derivation_, essentially a directory in
`/nix/store` with a weird name. For example

```
$ make onieInstaller
[ lots of build output ]
/nix/store/a6l2af11hipk8v0h002hcz3c1q9lzyyj-onie-installer-debian-buster
```

The installer itself is the file `onie-installer.bin` located in that
directory.  The root file system that will be installed by it will
only have a `root` account with an empty password and logins are only
possible from the serial console. To add user accounts to the image,
the installer has to be built with an additional argument. An example
of this is given by the make target `onieInstaller-SWITCH`:

```
onieInstaller-SWITCH:
	NIX_PATH= nix-build -j auto -A onieInstaller --argstr gitTag $(gitTag) \
	  --arg onieUsers '{ansible = {useraddArgs = "-s /bin/bash"; sshPublicKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDS/xdgmacIpg2bpsdqFETevQKPqyi3Pmn9lDaHQ/QYsz7eqsZAX/Tn+0NBL6sVb4C5g2Qk9EzKPs1v1F3p5bwaDq08aC+cRgKndWwjpZxj/MV0HQhzC5NpfBcE0TS5nzLJFjEs2qxQorZ07PglsYLCTxhe0vI36ddvfM1VIhc0Wa+h97CPjfIWNWUSAKKhjznpyJKONwWcHeM15MCzow6riDrHo14DsnoW9T68h3Qcd1RUUPx5xG6vd9cZ/7bAqru44RdDq4FUpkmPK+W6VN7bRqOxXC1TbKbptpeITcQdiBWblNgao9bvOtpxjXd1uEU0h9oqCsMn0tjIIsFYT2Wz ansible";};}'
```

It adds the user `ansible` with a specific SSH public key. This key is
only used inside SWITCH where the corresponding private key is stored
as part of an Ansible playbook. For the generic structure of this
parameter, see the documentation of the [`users` argument to
`mkOnieInstaller`](https://github.com/alexandergall/onie-debian-nix-installer/blob/master/README.md).

The standalone Installer can be built by

```
$ make standaloneInstaller
```

This will write the installer to `/tmp/standaloneInstaller`. It is a
self-extracting `bash` script that can be copied to the destination
system and executed there.

### <a name="buildingPreBuilt"></a>Installers From Pre-Built Packages

Installers based on pre-built releases can be reproduced locally.
This is necessary if you need an installer for the current development
version, because the CI system does not perform these builds on the
`master` branch.  To build the installers yourself, make sure that
your build host uses the proper binary caches by checking that
`/etc/nix/nix.conf` contains the lines

```
extra-substituters = https://cache.nixos.org http://p4.cache.nix.net.switch.ch
trusted-substituters = https://cache.nixos.org http://p4.cache.nix.net.switch.ch 
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= p4.cache.nix.net.switch.ch:cR3VMGz/gdZIdBIaUuh42clnVi5OS1McaiJwFTn5X5g=
```

Don't forget to run `systemctl restart nix-daemon` after changing this
files.  You can then proceed to build the `onieInstaller` and
`standaloneInstaller` packages as described in the previous chapter.
