let
  overlay = self: super:
    {
      net-snmp = (super.net-snmp.overrideAttrs (oldAttrs: rec {
        configureFlags = oldAttrs.configureFlags ++
          [ "--with-perl-modules"
            "--with-persistent-directory=/var/lib/snmp"
          ];
        preConfigure = ''
          perlversion=$(perl -e 'use Config; print $Config{version};')
          perlarchname=$(perl -e 'use Config; print $Config{archname};')
          installFlags="INSTALLSITEARCH=$out/lib/perl5/site_perl/$perlversion/$perlarchname INSTALLARCHLIB=$out/lib/perl5/site_perl/$perlversion/$perlarchname INSTALLSITEMAN3DIR=$out/share/man/man3"
        '';

        buildInputs = oldAttrs.buildInputs ++ [ self.libxcrypt ];

        ## The standard package uses multiple outputs, but this fails
        ## when Perl modules are enabled.  This override should be fixed
        ## to support this.
        outputs = [ "out" ];

        ## Make sure libsnmp is available before building the Perl modules
        enableParallelBuilding = false;

        ## Skip multi-output logic
        postInstall = "true";
      })).override { withPerlTools = true; };

      SNMPAgent = super.callPackage ./snmp {};
    };
in [ overlay ]
