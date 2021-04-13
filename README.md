# packet-broker-nixpkgs

Packaging of the [P4 Packet
Broker](https://github.com/alexandergall/bf-sde-nixpkgs) for the Nix
package manager

## Overview

The set of packages produced by this Nix expression provides a
complete deployment of the Packet Broker as an appliance on systems
based on the Tofino packet-processing ASIC.  It includes an ONIE
installer for the initial setup and a tool for managing releases on a
running system.

Currently, the base OS provided by the ONIE installer is a basic
version of Debian 10.9 combined with an installation of the [Nix
package manager](https://nixos.org/manual/nixpkgs/stable/).  While
Debian is used to manage the host itself, all components of the Packet
Broker service are provided by Nix. This repository depends on the
[Nix packaging of the Tofino
SDE](https://github.com/alexandergall/bf-sde-nixpkgs).  The main
advantages of using this framework are

   * Declarative style of package management: all properties and
     dependencies of software components are declared explicitly in a
     high-level description of the desired system
   * Precise dependency tracking: dependencies include all properties
     of the dependent package, not just its name and version
   * High level of reproducibility: given the declarative description
     of the system, anyone can reproduce the packages exactly
     (e.g. without any random dependencies on the environment of the
     build host)
   * Isolation from the package manager of the base OS: except for the
     kernel, the Nix packages are completely self-contained and do not
     depend on any packages of the host's native package manager

As a result, the system provides for very reliable deployments of the
service, avoiding many potential problems that are inherent with
traditional package managers. For example, random upgrades of any
Debian packages of the base OS have no impact on the functioning of
the Packet Broker service (except for a change of kernels as detailed
below)

The built-in release manager performs all interactions with the Nix
package manager on behalf of the user.  While no knowledge of Nix is
required to work with the system, the curious user is encouraged to
learn about this great tool as the key to reliable service deployment
:)

## Supported Platforms

The packages only support Tofino ASICs of the first generation at this
time.  Currently, the only verified platform is

   * `accton-wedge100bf-32x`

The system should also work on the 65x-variant
(`accton-wedge100bf-65x`) but has not been verified.

Other platforms that dont't have externel gearboxes to support
non-native port configurations are also expected to work, with the
possible exception of the management ethernet and CDC-ethernet (used
for communication between the host and the BMC) interfaces due to
different configurations of the PCIe bus.

## Initial Setup using the Pre-Built ONIE Installer

Devices like the `accton-wedge100bf-32x` usually come with a
pre-installed ONIE.  ONIE-compatible installers for releases of the
Packet Broker are [available for
download](http://hydra.nix.net.switch.ch/packet-broker/releases/). To
perform an installation, boot the system into "ONIE install
mode". Then copy the URL of the `onie-installer.bin` file for the
desired release and execute `onie-nos-install <URL>` at the `ONIE`
prompt. For example

```
# onie-nos-install http://hydra.nix.net.switch.ch/packet-broker/releases/1/onie-installer.bin
```

Note well: **This procedure destroys all partitions beyond partitions
1 and 2**. The EFI and ONIE partitions are preserved and the GRUB boot
loader includes an entry to chain-load the ONIE boot loader to make it
easy to perform ONIE operations after an image has been installed.

## Configuration and Usage

After the initial setup, the system has the following properties

   * No regular user account
   * Root access without password on the serial console only
   * The management interface is set up to perform DHCP
   * An empty Packet Broker configuration in
     `/etc/packet-broker/config.json`
   * A basic `snmpd` configuration in `/etc/snmp/snmpd.conf`, which
     does not allow any non-local connections

The OS can be freely configured as a regular Debian system. Changes to
the Debian packages will not impact the Packet Broker service in any
way, except for a change of kernel. This will be discussed further
later in this document.

### `systemd` services

The Packet Broker implements the following `systemd` services.

#### `packet-broker.service`

This is the main service unit, which runs the `bf_switchd` daemon to
excute the P4 program.

#### `packet-broker-configd.service`

This service units runs `configd` as a daemon. It is automatically
started and stopped with the main `packet-broker` service.

#### `snmpd.service`

This service runs an instance of the `net-snmp` SNMP daemon. It uses
the AgentX protocol to communicate with `snabb-snmp-agent.service`,
which provides the interfaces MIB for the interfaces controlled by the
packet broker.

#### `snabb-snmp-agent.service`

To make interface counters available via SNMP, the services `snmpd`
and `snabb-snmp-agent` must also be enabled (which is the default).
This also requires the configuration of access rules (SNMP community
strings and access-lists) in `/etc/snmp/snmpd.conf`.

### Packet Broker Configuration

To configuree the Packet Broker, edit `/etc/packet-broker/config.json`
and execute either

```
$ brokerctl reload
```

or

```
# systemctl reload packet-broker-configd
```

For a complete description of the available options and the
`brokerctl` command please refer to the [Packet Broker
documentation](https://github.com/alexandergall/packet-broker/blob/master/README.md)

### `bf_switchd` CLI

Use the `bfshell` command to enter the CLI provided by the
`bf_switchd` daemon.  Please refer to the documentation provided by
Intel on how to use the CLI.

## Release Management

The maintenance of releases of the Packet Broker service is performed
with a separate utility called `release-manager`, which is part of the
release itself.

Any number of releases can be installed on the system
concurrently. Only one of the releases is active at any given time and
it is possible to switch between any of the installed releases
arbitrarily.

Any commit on the master branch of this repository can be installed as
a release. By convention, specific Git tags are used to designate some
commits as _principal_ releases of the system.  They are intended to
capture major changes of the system like new or removed
features. Currently, a single number is used to identify principal
releases as detailed below.

It is expected that regular users only install principal releases on
their system.  However, it is possible for anyone to install releases
corresponding to aritrary Git commits if desired.

One practical difference betwen a prinicpal and a non-principal
release is that the CI system used to build the packages only creates
installers for principal releases.

### Release Contents and Versioning

A release of the Packet Broker service is comprised of the following
components

   * `packet-broker`. A command which starts the `bf_switchd`
     process provided by the Tofino SDE with the compiled
     `packet-broker` P4 program.
   * `packet-broker-module-wrapper`. A wrapper script around
     `packet-broker`, which loads the appropriate kernel module before
     starting `bf_switchd`.
   * `configd`. A command that starts the control-plane process, which
     reads the configuration file and programs the match-action-units
     on the ASIC accordingly. It also communicates with the
     `brokerctl` CLI utility.
   * `systemd` service units. A set of unit files for the
     `packet-broker`, `packet-broker-configd`, `snmpd` and
     `snabb-snmp-agent` services.
   * `bf-utils`. A package provided by the SDE which includes the
     `bfshell` command used to start a CLI session with the running
     `bf_switchd` process.
   * `release-manager`. A command to manage releases of the service.
   * `version`. A file containing the version information of the
     release.

Each of these components is a package by itself in the sense of the
Nix package manager.  In other words, the release is a collection of
packages which is treated as a unit by the release manager.

The `version` file contains a string of the form `<version>:<gitTag>`,
uniquely identifying the release as follows.

#### `<version>`

This is a monotonically increasing number which identifies the
principal releases of the Packet Broker.

Each principal release is tagged with an annotated Git tag of the form
`release-<version>`.  This tag is used by the `release-manager` to
find releases available for installation via the Github API.

#### `<gitTag>`

The `<gitTag>` is the output of the command `git describe --always`
executed in the top-level directory of the repository for the specific
commit from which the release was created.  This gives the "distance"
of the commit to the closest annotated tag reachable from the commit
in the form `<tag>-<n>-g<commit>`, where `<tag>` is the name of the
annotated tag, `<n>` is the number of commits following the tagged
commit and `<commit>` is the abbreviated commit itself.

The `<tag>` is always of the form `release-<version>`, see the
previous section.

By definition, `<gitTag>` is equal to `release-<version>` for
principal releases.

All commits on top of a principal release can be considered to be
minor releases of that principal release with the same value of
`<version>`.

### Installation and Kernel Support

The SDE includes a set of kernel modules needed by the `bf_switchd`
process.  Every kernel for which these modules should be built must be
explicitly supported by the SDE package. The [list of supported
kernels](https://github.com/alexandergall/bf-sde-nixpkgs/blob/master/bf-sde/kernels/default.nix)
is part of the SDE package definition.

A release of the Packet Broker includes the modules for all supported
packages.  At the time of installation on a specific target, only the
modules that match the local kernel will be installed.  This implies
that a release cannot be installed on an unsupported kernel.

As a result, only a subset of the components contained in the release
is installed on any given target. This subset is referred to as a
_slice_ of the release. By definition, all slices have the same
version information. Since it is possible to install multiple slices
on a system to support kernel upgrades or multi-kernel configurations,
it is necessary to distinguish them from each other. For this purpose,
each slice includes a file called `slice`, containing the identifier
of the kernel in the form `<kernelID>:<kernelRelease>`.

The `<kernelID>` is already a unique identifier for the
kernel. Technically, it is the name of the attribute in a set that
defines the [properties of every supported
kernel](https://github.com/alexandergall/bf-sde-nixpkgs/blob/master/bf-sde/kernels/default.nix)
in the `bf-sde-nixpkgs` Nix expression, e.g. `Debian10_8` or
`ONL9`. Each such definition includes the exact kernel release
identifier of that kernel, which is the result of running `uname -r`
on a running instance of the kernel.

The kernel release string is included in the slice identifier as the
`<kernelRelease>` string.  The sole purpose of this is to make it
explicit to the administrator for which kernel a release has been
built when looking at an installed instance. For example, the
following one-to-one correspondence holds for the kernels with
`kernelID` `Debian10_8` and `Debian10_9`

   * `<kernelID>` = `Debian10_8` <=> `<kernelRelease>` = 4.19.0-14-amd64
   * `<kernelID>` = `Debian10_9` <=> `<kernelRelease>` = 4.19.0-16-amd64


### Standalone Release Installer

## Building

Building the installer (or any other part of the system) yourself
requires the presence of the Nix package manager and access to the
Tofino SDE from Intel (currently available only by signing an NDA with
Intel). For details please refer to the first section of the
[documentation of the SDE Nix
package](https://github.com/alexandergall/bf-sde-nixpkgs#bf-sde-nixpkgs). You
need to perform the steps

   * [Install the Nix package manager in multi-user
     mode](https://github.com/alexandergall/bf-sde-nixpkgs#install-the-nix-package-manager-in-multi-user-mode)
   * [Fetch and verify source
     archives](https://github.com/alexandergall/bf-sde-nixpkgs#fetch-and-verify-source-archives)
     for version 9.4.0 of the SDE
   * [Add archives to the Nix
     store](https://github.com/alexandergall/bf-sde-nixpkgs#add-archives-to-the-nix-store)

Then clone this repository

```
$ git clone https://github.com/alexandergall/packet-broker-nixpkgs.git
```

Check out the desried release, e.g.

```
$ cd packet-broker-nixpkgs
$ git checkout release-1
```

To build the ONIE installer, execute

```
$ nix-build -A onieInstaller
```

This will build everything from the SDE source code and take between
30 and 60 minutes, depending on your build host.

To build the standalone installer:

```
$ nix-build -A releaseInstaller
```

The resulta are Nix _derivation_, essentially a directory in
`/nix/store` with a weird name. For example

```
```

The installer itself is the file `onie-installer.bin` located in that
directory.

## Service Management



### The Release Manager

All manipulations of releases are performed with the `release-manager`
CLI tool which is part of every release. It supports the following
options

   * `--list-installed`
   * `--list-available`
   * `--switch-to-generation <gen>`
   * `--install-release <version>`
   * `--install-git <git-rev>`
   * `--untinstall-generation <gen>`
   * `--activate-current`
   * `--deactivate-current`
   * `--cleanup`

Every ONIE installer has a specific release of the Packet Broker built
into the image.  It can be displayed with

```

```


On a fresh installation with the ONIE installer, a single release is
available, 
