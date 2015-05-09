#!/usr/bin/perl 

# log usage
`ulog $$ $0 @ARGV  > /dev/null 2>&1 &`;

##############################################################################
# History:
# 11-May-2010: SML -- Add logDaemon processing
# 04-Feb-2014: MJC -- Add DDD support
##############################################################################

use Getopt::Std;
use Benchmark;
use File::Find;

#
# According to perldoc Getopt::Std, this has to be set true to avoid
# getopt's paranoia code from running.  This allows --help and --version only 
# to work.
#
$Getopt::Std::STANDARD_HELP_VERSION = 1;

#
# Each dump location is of the form:
#
# 'dump directory' => 'number of directory levels to search'
#

$custom_dir = 0;  # Just a var to trick Perl's getopts
my $branch = "sspg";

#
#  Path is the key and directory level search is the value.
#  A level of 1 means only check the parent.  Level defines the
#  search depth of the dir mentioned.
#
%locations =   (

      #
      # RTP Engineering Dump Locations
      #

      rtp_eng =>  {
                     "/c4site/RTP/coredumps"            => 1,
                  },

      rtp_eng2 =>  {
                     "/c4site/RTP/coredumps2"            => 1,
                  },

      #
      # Sobo Engineering Dump Locations
      #

      sobo_eng => {
                     "/c4site/SOBO/coredumps"           => 1,
                  },

      #
      # Customer Dump Locations
      #

      customer => {
                     "/disks/NSG_Crash_Dump_Field" => 1,
                  },

      customer2 => {
                     "/disks/NSG_Crash_Dump_Field2" => 1,
                   },

   );

#
# Usage information
#

$usage = <<"EOU"

   Usage:

      $0
         ( -d <dir> | -z <dump> | -i <defect> [-c] [-a] )  # Required
         [-e] [-s < source view path > -b < branch name] > # Optional 
         [-g < gdb RPM file >]                             # Optional
         [-G < gdb executable >]                           # Optional
         [-D]                                              # Optional
         [-h]                                              # Optional 
         [-f <personal gdb commands file>]                 # Optional

      -d       Directory
      -D       Use /usr/bin/ddd debugger instead of GDB
      -f       Full path to file containing personal GDB commands to run.
      -z       Dump File
      -i       Defect Number.  
               Using -c with -i includes customer /disks shares.  
               Using -a with -i includes a directory of your choosing in the search order.
      -e       EvilDump Verbose (Debug) Output
      -h       Shows this help output.  Overrides all other options.
      -s/-b    Search/Replace option pair used to help with "set substitute" path
               gdb command.  Using this option sets the substitute-path permanently in the
               gdb init file created by evildump.pl locally.
               These two options must be used together.
      -g       Use user provided gdb RPM image instead of the one from the build.
      -G       Use user provided gdb binary instead of the one from the build.

      Notes: The environment variable _EVIL_DUMP_OPTIONS will be appended
             to all commands.

EOU
;



my @directory_candidates = ();
my @dump_pretty_path_candidates = ();
my @dump_path_candidates = ();
my @tar_files = ();

my $max_zip_extractions    = 4;
my $max_windbg_extractions = 4;
my $stats_file             = "/coredumps/resources/edstats.txt";
my $cmds_dir               = "/coredumps/tools/bin/edmotd";
my $summary_cmds_file      = "/coredumps/tools/bin/evildumpsummcmds.txt";

my $first = 1;
my $gdb_override = "";
my $gdb_bin_override = "";

sub massage_options
{

   if ( !@ARGV )
   {
      return;
   }

   if ( $ENV{_EVIL_DUMP_OPTIONS} )
   {
      unshift @ARGV, split(/ /,$ENV{_EVIL_DUMP_OPTIONS});
   }

   #
   # Run through the arguments real quick and "fix up" the shorthand case
   # where just a defect number is given.
   #

   @ed_opt = split(/ */,$ed_opts);

   while ( @ARGV )
   {
      $a = $ARGV[0];

      #
      # Is this an option?
      #

      if ( $a =~ /^-(.)(.*)/ )
      {
         ($first,$rest) = ($1,$2);
         $pos = index($ed_opts,$first);

         #
         # Does this option take an argument?
         #

         if ( ($ed_opt[$pos+1] eq ':') )
         {
             $arg_list = "$arg_list $a";

             #
             # Is the option 'd' (Directory)?
             #

             if ($first eq 'd')
             {
                $temp_option = shift (@ARGV); # Store the option
                @temp_copy = @ARGV; # use a copy instead of original

                #
                # Go through the args looking for spaces or more options
                #

                 foreach $element (@temp_copy)
                 {

                 #
                 #   Is it an option? if yes Quit, else concat
                 #   the args into one (One Directory with spaces if needed)
                 #

                     if (!($element =~/^\-./))
                     {
                          $piece = shift(@ARGV);
                          $name = "$name $piece";
                     }
                     else
                     {
                          last;
                     }

                 }

                 unshift(@ARGV,"$name");  # Put a dummy name meanwhile
                 unshift(@ARGV, $temp_option); # Put back the option we took
             }

             shift( @ARGV );
             $a = $ARGV[0];
         }

         $name =~ s/^\s//; # Replace space with "
         $custom_dir = $name;
         $arg_list = "$arg_list $a";

         shift( @ARGV );
      }
      else
      {
         $arg_list = "$arg_list -i $a";
         shift( @ARGV );
      }
   }

   @ARGV = split(/ /,$arg_list);

   # eat the null first argument.
   shift ( @ARGV );

   return;
}


#  Given a <parent> directory, find and return a child directory which
#  contains <dir> at <level> depth
sub find_dir
{
   my( $parent, $dir, $level ) = @_;

   print "find_dir: enter $parent, $dir, $level\n" if $debug;

   my $my_dir;

   return $my_dir if ( ! -d $parent );

   opendir( DIR, $parent ) || die "Cannot open $parent";
   my @list = readdir( DIR );
   closedir( DIR );
   @list = reverse @list;

   # 
   #   Check for . and ..
   # 
   return $my_dir if ( "$dir" =~ m/^\.\./ );
   return $my_dir if ( "$dir" =~ m/^\./ );
   
   if ( $level == 1 )
   {
      print "Checking: $parent\n" if $debug;

      print "dir:  $dir\n" if $debug;
      if ( -d "$parent/$dir" )
      {
         return "$parent/$dir";
      }

      my $count = 0;

      for my $l ( @list )
      {
         #if ( "$parent/$l" =~ /$dir/ig )
         if ( "$parent/$l" =~ m/($dir)/ )
         {
             next if ( "$l" =~ m/^\.\./ );
             next if ( -f $l );

            print "find_dir: found directory candidate $parent/$l\n" if $debug;

            push @directory_candidates, "$parent/$l";
         }
      }

      if ( scalar @directory_candidates eq 1 )
      {
          $my_dir = $directory_candidates[0];
      }
   }
   else
   {
      for my $l ( @list )
      {
         next if $l eq '.';
         next if $l eq '..';
         next if $l eq 'lost+found';

         $my_dir = find_dir ( "$parent/$l",
                              $dir,
                              $level - 1 );

         last if( $my_dir );
      }
   }

   print "find_dir: exit $my_dir\n" if $debug;

   return $my_dir;
}

sub find_files
{
    my $name = $_;
    my $full_path_name = $File::Find::name; 
    my $dirname = $File::Find::dir;


    if ( -d "$name" )
    {
	return;
    }

    if ( $name =~ /\.tar\.gz$/ )
    {
        if ( $full_path_name =~ /binaries/ )
        {
            if ( -d "EMC" && -d "opt")
            {
                return;
            }
        }
	if (! (-e "$name.touched")) {
            printf "Found compressed tar file:  $name\n";
            system("/bin/tar --keep-old-files --atime-preserve -zxf $name ");
            system ("chmod -R a+rw ./\* 2> /dev/null");
	    system("touch $name.touched");
	}
	else {
	    printf "Already handled tar file: $name\n" if $debug;
	}
    }
    elsif ( $name =~ /\.tar$/ )
    {
        if ( $full_path_name =~ /C4Core_dump_/)
        {
            if ( -d "tmp"  || -d "cores" )
            {
                printf "Skipping tar file:  $name\n" if $debug;
                return;
            }
        }
	if (! (-e "$name.touched")) {
          printf "Found tar file:\t\t$name\n";
          system("/bin/tar --keep-old-files --atime-preserve -xf $name ");
          system "chmod -R a+rw ./\* 2> /dev/null";
	  system("touch $name.touched");
        }
	else {
	    printf "Already handled tar file: $name\n" if $debug;
	}
    }
    elsif ( $name =~ /\.gz$/ ) 
    {
	($newname = $name) =~ s/.gz//;
	if ( ! -f $newname ) {
           printf "Uncompressing file:  $name\n";
           system("/usr/bin/gzip -f -d -c $name > $newname");
	}
	else {
	   printf "Using already unzipped file: $newname\n" if $debug;
	}
    }
}

sub determine_dump_files
{
    my $name = $_;
    my $full_path_name = $File::Find::name; 
    my $dirname = $File::Find::dir;

    my $found = 0;

    if ( -d "$name" )
    {
        return;
    }

    if ( ( ( "$name" =~ /(\z*ccsx*)/ )  || 
           ( "$name" =~ /(\z*_safe)/ ) ||
           ( "$name" =~ /(\z*cdxic*)/ ) ||
           ( "$name" =~ /(\z*gms*)/ ) ||
           ( "$name" =~ /(\z*core*)/ ) ||
           ( "$name" =~ /(\z*logDaemon*)/ ) ||
           ( "$name" =~ /(\z*ECOM*)/ ) ||
           ( "$name" =~ /(\z*fbecli_*)/ ) ||
           ( "$name" =~ /(\z*mnsvcd*)/ ) ||
           ( "$name" =~ /(\z*mgmtd*)/ ) ||
           ( "$name" =~ /(\z*clariiontool*)/ ) ||
           ( "$name" =~ /(\z*RemoteAgent*)/ ) ||
           ( "$name" =~ /(\z*NDU*)/ ) ||
           ( "$name" =~ /(\z*newSP*)/ ) ||
           ( "$name" =~ /(\z*MluCli*)/ ) ||
           ( "$name" =~ /(\z*PEServ*)/ ) ||
           ( "$name" =~ /(\z*sedcli*)/ ) ||
           ( "$name" =~ /(\z*psmtool_*)/ ) ||
           ( "$name" =~ /(\z*KdbmTool*)/ ) ||
           ( "$name" =~ /(\z*umpsSend*)/ ) ||
           ( "$name" =~ /(\z*rt_collector*)/ ) ||
           ( "$name" =~ /(\z*crmd*)/ ) ||
           ( "$name" =~ /(\z*obs_hist*)/ ) ||
           ( "$name" =~ /(\z*TLD*)/ ) ||
           ( "$name" =~ /(\z*AdminTes*)/ ) ||
           ( "$name" =~ /(\z*admin*)/ ) ) &&
           ( "$name" !~ /(\z*\.so*)/ ) &&
           ( "$name" !~ /(\z*\.txt*)/ ) )
    {
#       
#       We only care about file that are core dumps.
#
        if ( ( "$name" !~ /C4Core/ ) &&
             ( "$name" !~ /safe/ ) &&
             ( "$name" !~ /CP_dump.*ECOM/ ) &&
             ( "$name" !~ /_admin/ ) &&
             ( "$name" !~ /core-/ ) &&
             ( "$name" !~ /logDaemon.*\.core$/ ) )
        {
            return;
        }
        elsif ( ( "$name" != /tar$/ ) || 
                ( "$name" != /gz$/ ) || 
                ( "$name" != /lst$/ ) || 
                ( "$name" != /lib$/ ) || 
                ( "$name" != /tar\.gz$/ ) )
        {
            return;
        }
	# Skip log files.
	if ( ( $name =~ /\.log$/) ||
	     ( $name =~ /\.xsd$/) ||
	     ( $name =~ /\.log\./) ) 
	{
	    return;
	}
        $found = 0;
        for my $k ( @dump_pretty_path_candidates )
        {
            if ( "$k" =~ "$full_path_name" )
            {
                $found = 1;
                break;
            }
        }
                
        if ( ! ( $found ) )
        {
            push @dump_pretty_path_candidates, "$full_path_name";
        }

    }

}

sub get_version_file
{
    my ( $dump_path )=@_;
    my $dump_dir;
    my $pos =rindex($dump_path,"/");
    if($pos != -1)
    {
        $dump_dir = substr($dump_path, 0 ,$pos);
    }
    else
    {
        $dump_dir = ".";
    }

    return $dump_dir."/version";
}

#In KH, the build version and OS version were move out of the core file name and stored in a file named 'version'.
#The version file is saved in the same folder as the core file
sub get_kh_dump_info
{
    my ($dump_path) =@_;
    my $buid_ver, $os_ver;
    my $file_path =get_version_file($dump_path);
    my $file;
    if( -f $file_path && open($file, "<", $file_path) )
    {
        chomp($buid_ver =<$file>); #The first line contains the build version for this core dump
        <$file>;            #skip the second line containing the chasiss SN
        chomp($os_ver =<$file>);   #The third line contains the OS version
    }
    return ($buid_ver, $os_ver);
}

#
# Given the dump path name, return the build type (RETAIL or DEBUG)
#
sub get_build_type
{
    my ( $dump_path_name ) = @_;

    if( $dump_path_name =~ /DEBUG/ ) {
        return "DEBUG";
    } elsif( $dump_path_name =~ /RETAIL/ ) {
        return "RETAIL";
    } else {
        return "";
    }
}
#
# Given the dump path, return the build number
#
sub get_build_num
{
    my ( $dump_path ) = @_;
    my $build_ver;
    my $build_num;
    $build_type = get_build_type( $dump_path );

    if ( $build_type )
    {
        $build_ver =$dump_path;
    } else {
        my $temp;
        ( $build_ver, $temp) = get_kh_dump_info($dump_path);
        if( $build_ver =~ /DEBUG/ ) {
            $build_type = "DEBUG";
        } elsif ($build_ver =~ /RETAIL/) {
            $build_type = "RETAIL";
        }
        else {
            die "version file does NOT exist in the core file folder or unrecognized\n";
        }
    }

    print "DEBUG: get_build_num( $dump_path, $build_type)\n" if $debug;

    $_ = $build_ver;
    if( $build_type =~ RETAIL ) {
        /(\d+)\-[^\-]+\-RETAIL/;
        $build_num = $1;
    } elsif($build_type =~ DEBUG) {
        /(\d+)\-[^\-]+\-DEBUG/;
        $build_num = $1;
    }else {
        die "Dump path does not contain DEBUG or RETAIL: $dump_path\n";
    }

    return $build_num;
}
#
# Given the dump path, return the branch name
#
sub get_branch_name
{
    my ( $dump_path ) = @_;
    
    $_ = $dump_path;
    /C4Core_dump_sp._(.+?)-/;

    print "DEBUG: get_branch_name( $dump_path ): $1\n" if $debug;
    return $1;
}

#
# Locate the BOM (Bill of Material) file for this build (for the DEBUG flavor)
#
sub find_bom
{
    my ($dump_path_name) = @_;

    my $build_num = get_build_num( $dump_path_name );
    my $build_branch = get_branch_name( $dump_path_name );

    print "find_bom:  build_num=$build_num.  build_branch=$build_branch\n" if $debug;
    return "/c4shares/re/Results/c4build/*/*$build_branch*$build_num*/*DEBUG-MAGNUM*/Dist/rpm*";
}

#
# Is evildump running in SLES11 or SLES11 SP1?
#
sub find_running_environment
{
    $suse = `cat /etc/SuSE-release`;
    
    printf(">>>$suse<<< \n") if $debug;
    
    if(($suse =~ /VERSION = 11/) && ($suse =~ /PATCHLEVEL = 0/)) {
        printf("Running environment: SLES 11\n") if $debug;
        return "SLES11";
    } elsif(($suse =~ /VERSION = 11/) && ($suse =~ /PATCHLEVEL = 1/)) {
        printf("Running environment: SLES 11 SP 1\n") if $debug;
        return "SLES11SP1";
    } elsif(($suse =~ /VERSION = 11/) && ($suse =~ /PATCHLEVEL = 2/)) {
        printf("Running environment: SLES 11 SP 2\n") if $debug;
        return "SLES11SP2";
    } elsif(($suse =~ /VERSION = 11/) && ($suse =~ /PATCHLEVEL = 3/)) {
        printf("Running environment: SLES 11 SP 3\n") if $debug;
        return "SLES11SP3";
    }
    die "Unsupported development platform: $suse";
}

#
# Was dump based on SLES11, SLES11 SP1 or SLES11 SP2?
#
sub find_dump_environment
{
    my ($dump_path_name) = @_;
    my $bom = find_bom($dump_path_name);
    my $rc = "UNSUPPORTED";

    print "find_dump_environment:  BOM = $bom\n" if $debug;

    # With the introduction of Kittyhawk/SLES 11 SP 2, the OS 
    # release is now part of the dump path.  First, explicitly 
    # test for SP2.

    my $version_file =get_version_file($dump_path_name);
    if ( -f $version_file )
    {
        my $build_ver, $os_ver;
        ( $build_ver, $os_ver ) = get_kh_dump_info($dump_path_name);
        if( ! $os_ver )
        {
            die "unrecognized version file: $version_file";
        }
        $rc = $os_ver;
    }
    elsif ( "$dump_path_name" =~ /DEBUG_SLES11SP2/ ||
	 "$dump_path_name" =~ /RETAIL_SLES11SP2/ )
    {
        $rc = "SLES11SP2";
    } 
    # if not SP2 and it's one of the below binaries, then it's SP1
    elsif ( ( "$dump_path_name" =~ /(safe)/ )     ||
              ( "$dump_path_name" =~ /(fbecli_)/ ) ||
              ( "$dump_path_name" =~ /(ECOM)/ ) ||
              ( "$dump_path_name" =~ /(mnsvcd)/ ) ||
              ( "$dump_path_name" =~ /(mgmtd)/ ) ||
              ( "$dump_path_name" =~ /(clariiontool)/ ) ||
              ( "$dump_path_name" =~ /(RemoteAgent)/ ) ||
              ( "$dump_path_name" =~ /(NDU)/ ) ||
              ( "$dump_path_name" =~ /(newSP)/ ) ||
              ( "$dump_path_name" =~ /(TLD)/ )      ||
              ( "$dump_path_name" =~ /(AdminTes)/ )      ||
              ( "$dump_path_name" =~ /(umpsSend)/ ) ||
              ( "$dump_path_name" =~ /(rt_collector)/ ) ||
              ( "$dump_path_name" =~ /(crmd)/ ) ||
              ( "$dump_path_name" =~ /(obs_hist)/ ) ||
              ( "$dump_path_name" =~ /(MluCli)/ ) ||
              ( "$dump_path_name" =~ /(PEServ)/ ) ||
              ( "$dump_path_name" =~ /(sedcli)/ ) ||
              ( "$dump_path_name" =~ /(KdbmTool)/ ) ||
              ( "$dump_path_name" =~ /(gms_svr)/ ) ||
              ( "$dump_path_name" =~ /(psmtool_)/ ) )
    {
            $rc = "SLES11SP1";
    }
    # Last resort, look at the bill of material
    else
    {
        open BOM, "grep \"RPM_NAME kernel-\" $bom |" or die "can't open bill of material grep pipe";
        while (<BOM>) 
        {
            print if $debug;
            if( /SLES11SP1\.NEO/    ) {
                $rc = "SLES11SP1";
                break;
            }
            if( /SLES11\.NEO/ ) {
                $rc = "SLES11";
                break;
            }
        }
        close BOM;
    }

    die "Dump environment is unsupported" if( $rc =~ UNSUPPORTED ) ;
    print "Dump environment is $rc\n" if $debug;
    return $rc;
}


#
# Given the dump path name, find the RPM file that contains the GDB binary.
#
# Returns ''  if unable to find RPM file.
#
sub find_gdb_rpmfile
{
    my ($dump_path_name) = @_;
    my $floc, $dirname, $gdb_file;

    # GDB only lives in the DEBUG build.  So use DEBUG whether we are DEBUG or RETAIL
    my $bom_file = find_bom($dump_path_name);

    print "DEBUG: bom_file: >$bom_file<\n" if $debug;
    # Scan the bill of materials, looking for the gdb RPM.
    # Modern entries looks like this:
    #
    # : gdb
    #   FTP_LOC file:///c4shares/re/Results4/c4build/c4build7/Suite-rpms-infq-NeoMain-r4072/build-rpms-infq-NeoMain-r4072-RETAIL-MAGNUM/Dist/
    #   LIST_ID rpmlist_opensrc_v3
    #   RPM_NAME gdb-6.8.50.20081120-5.12.emc4072
    #   DEBUG
    #   SLES11

    my $line_number = 0;
    my $found_gdb   = 0;
    my $found_dir   = 0;
    my $found_file  = 0;
    open BOM_LOC_PIPE, "cat $bom_file |" or die "cannot open bill of material: $!\n";
    while (<BOM_LOC_PIPE>)
    {
    $line_number++;
    print "DEBUG: >>$_" if $debug; 
    if( ! $found_gdb ) {
        next if (! /^: gdb$/);
        $found_gdb = 1;
        print "DEBUG: Found : gdb\n" if $debug; 
    } elsif( ! $found_dir ) {
        $found_gdb = 0 if (/^:/);
        next if (! /FTP_LOC file:/);
        print "DEBUG: Found : FTP_LOC\n" if $debug; 
        chomp;
        ($floc, $dirname) = split(/^*FTP_LOC file:/);
        $found_dir = 1;
    } elsif( ! $found_file ) {
        next if(! /RPM_NAME/);
        print "DEBUG: Found : RPM_NAME\n" if $debug; 
        chomp;
        ($floc, $gdb_file) = split(/^*RPM_NAME /);
        # Concatenate the CPU arch
        $gdb_file = $gdb_file . ".x86_64.rpm"; 
        $found_file = 1;
    }
    }
    close BOM_LOC_PIPE;
    print "DEBUG: gdb:$found_gdb.  dir:$found_dir.  file:$found_file\n" if $debug;

    if( $found_gdb && $found_dir && $found_file ) {
    $gdb_rpmfile = $dirname . $gdb_file;
    print "DEBUG: gdb_rpmfile: $gdb_rpmfile\n" if $debug; 
    return( $gdb_rpmfile );
    }
    #
    # The BOM file did not include a gdb entry with an FTP_LOC field.
    # 
    print "DEBUG: Unable to find GDB: gdb:$found_gdb.  dir:$found_dir.  file:$found_file\n" if $debug;
    return( '' );
}
#
# Given the dump path name, find the appropriate GDB binary and install it in
# $destination_path.  $destination_path is a file name, not a directory name.
#
# The gdb binary could come from several sources.  We want to select one in this order:
# 1) From the user provided override, if present
# 2) From the build (extracted from the RPM).  If that's not available then
# 3) From the old default
#
# Note: this function will overwrite $destination_path
#
sub install_gdb
{
    my ($dump_path_name, $destination_path, $dumpenv) = @_;

    my $rpm_file; 

    # If the user provided an override, use that.
    if( $gdb_override ne "" ) {
	print "DEBUG: Using specified GDB RPM override file: $gdb_override\n" if $debug;
	$rpm_file = $gdb_override;
    }
    
    else {   
	($rpm_file) = find_gdb_rpmfile $dump_path_name;
    }

    print "\nDEBUG: find_gdb: The RPM file is >$rpm_file<.\n\n" if $debug; 
    if( ! $rpm_file eq '' ) 
    {
        #
        # Extract gdb from the RPM
        #
        print "Extracting gdb from $rpm_file.\n"; 
        system("rpm2cpio $rpm_file | cpio --extract --to-stdout \"./usr/bin/gdb\" > $destination_path");
    } 
    else 
    {
	# No RPM, nothing already in the dump - use the distribution default
	print "Unable to locate gdb RPM file, installing default\n";
	unless ( -f "/c4shares/auto/devutils/bin/gdb_$dumpenv" ) {
	    die "Unable to locate default gdb file /c4shares/auto/devutils/bin/gdb_$dumpenv";
	}
	system("cp -v /c4shares/auto/devutils/bin/gdb_$dumpenv $destination_path");
    } 

    system("chmod -v 777 $destination_path 2> /dev/null");
}

#routine to determine dump bitness
sub ELFxx
{
    my $elf_head = `readelf -h @_ 2>&1`;
    if($? or $elf_head =~ /^readelf: Error:/) {
        my $from = (caller(1))[3];
        my $lineno = (caller(1))[2];
        print "ERROR: unknown dump file format @_ (corrupt?)\n";
        die "Called from $from, line $lineno" if $debug;
    }
    return "64" if($elf_head =~ /Class:.*ELF64/);
    return "32" if($elf_head =~ /Class:.*ELF32/);
    die "ERROR: unknown dump file format\n"
}

sub start_gdb
{
    my ( $my_dump_path_name, $my_source_path, $my_use_ddd ) = @_;

    my $my_dump_path = $my_dump_path_name;
    my $using_ddd = $my_use_ddd;

    if($using_ddd) 
    {
        print "use /usr/bin/ddd specified\n";
    }

    my $my_lib_prefix;
    my $home = "$ENV{HOME}";
    #
    # Verify the debug environment works with the build environment
    #
    my $runningenv = find_running_environment();
    my $dumpenv    = find_dump_environment($my_dump_path_name);

    print "Verifying the dump and running environment match.\n" if $debug;
    print "Running Environment: $runningenv.  Dump Environment: $dumpenv\n" if $debug;
    if($runningenv ne $dumpenv) {
        if($dumpenv eq "SLES11SP3") 
        {
            print "\n=========================================================================\n";
            print "You need to execute evildump in a SLES11 SP3 environment.\n";
            print "execute \"gosp3\" before evildump.  See\n\n"; 
            print "sforge.sspg.lab.emc.com/sf/wiki/do/viewPage/projects.c4lx/wiki/ChrootBuildEnv\n\n";
            print "for details.";
            print "\n=========================================================================\n";          
        } 
        elsif($dumpenv eq "SLES11SP2") 
        {
            print "\n=========================================================================\n";
            print "You need to execute evildump in a SLES11 SP2 environment.\n";
            print "execute \"gosp2\" before evildump.  See\n\n"; 
            print "sforge.sspg.lab.emc.com/sf/wiki/do/viewPage/projects.c4lx/wiki/ChrootBuildEnv\n\n";
            print "for details.";
            print "\n=========================================================================\n";          
        } 
        elsif($dumpenv eq "SLES11SP1") 
        {
            print "\n=========================================================================\n";
            print "You need to execute evildump in a SLES11 SP1 environment.\n";
            print "execute \"gosp1\" before evildump.  See\n\n";
            print "sforge.sspg.lab.emc.com/sf/wiki/do/viewPage/projects.c4lx/wiki/ChrootBuildEnv\n\n";
            print "for details.";
            print "\n=========================================================================\n";
            
        } 
        elsif($dumpenv eq "SLES11")
        {
            print "\n=========================================================================\n";
            print "You need to execute evildump in a SLES11 SP0 environment.\n";
            print "\n=========================================================================\n";
        }
        die "Running ($runningenv) and Dump ($dumpenv) environments don't match" ;
    }
    if ($my_dump_path =~ m#/#) {
        $my_dump_path =~ s#/[^/]+$##;
        chomp( $my_lib_prefix = `cd $my_dump_path; pwd` ); #absolute path to unpacked corebump bundle here
    } else {
        $my_dump_path = "$ENV{PWD}";
        $my_lib_prefix = "$ENV{PWD}";
    }
          
    $ENV{LD_LIBRARY_PATH} = "" if(!$ENV{LD_LIBRARY_PATH}); #just to override annoying perl warning
              
    #adding LD_LIB paths for proper search of fdb macros, csx runtime libs and system libs
    $ENV{LD_LIBRARY_PATH}=
        "$my_lib_prefix/lib64:".
        "$my_lib_prefix/lib:".
        "$my_lib_prefix/usr/lib64:".
        "$my_lib_prefix/EMC/C4Core/lib/gdb_macros:".
        "$my_lib_prefix/EMC/csx/ulib64:".
        "$my_lib_prefix/EMC/C4Core/bin:".
        "$my_lib_prefix/EMC/CST/lib:".
        "$my_lib_prefix/EMC/CST/lib32:".
        "$my_lib_prefix/EMC/c4_logging/lib:".
        "$my_lib_prefix/EMC/c4_logging/lib32:".
        "$my_lib_prefix/opt/safe/safe_binaries/kernel/exec:".
        "$my_lib_prefix/opt/safe/safe_binaries/user/exec:".
        "$my_lib_prefix/opt/safe/safe_binaries/user32/exec:".
        $ENV{LD_LIBRARY_PATH};

          
    my $gdb_path;
    my $ic_path;

    my $local_gdb_path; 
    my $local_gdb_dir; 

    #
    #  This is the gdb code to handle the SAFE cores and dumps.
    #
    if ( ( "$my_dump_path_name" =~ /(safe)/ ) ||
         ( "$my_dump_path_name" =~ /(fbecli_)/ ) ||
         ( "$my_dump_path_name" =~ /(ECOM)/ ) ||
         ( "$my_dump_path_name" =~ /(mnsvcd)/ ) ||
         ( "$my_dump_path_name" =~ /(mgmtd)/ ) ||
         ( "$my_dump_path_name" =~ /(clariiontool)/ ) ||
         ( "$my_dump_path_name" =~ /(RemoteAgent)/ ) ||
         ( "$my_dump_path_name" =~ /(NDU)/ ) ||
         ( "$my_dump_path_name" =~ /(newSP)/ ) ||
         ( "$my_dump_path_name" =~ /(TLD)/ ) ||
         ( "$my_dump_path_name" =~ /(AdminTes)/ ) ||
         ( "$my_dump_path_name" =~ /(umpsSend)/ ) ||
         ( "$my_dump_path_name" =~ /(rt_collector)/ ) ||
         ( "$my_dump_path_name" =~ /(crmd)/ ) ||
         ( "$my_dump_path_name" =~ /(obs_hist)/ ) ||
         ( "$my_dump_path_name" =~ /(MluCli)/ ) ||
         ( "$my_dump_path_name" =~ /(PEServ)/ ) ||
         ( "$my_dump_path_name" =~ /(sedcli)/ ) ||
         ( "$my_dump_path_name" =~ /(KdbmTool)/ ) ||
         ( "$my_dump_path_name" =~ /(gms_svr)/ ) ||
         ( "$my_dump_path_name" =~ /(psmtool_)/ ) )
    {
        $local_gdb_path = "$my_dump_path/usr/bin/gdb";     
        $local_gdb_dir = "$my_dump_path/usr/bin";

    }
    else
    {
        $local_gdb_path = "$my_dump_path/EMC/csx/ubin".ELFxx($my_dump_path_name)."/gdb";     
        $local_gdb_dir = "$my_dump_path/EMC/csx/ubin".ELFxx($my_dump_path_name);

    }

    if ( ! -e $local_gdb_dir ) 
    {
        print "Creating local gdb dir\n";
        system("mkdir -p $local_gdb_dir");
        system("chmod -R a+w $local_gdb_dir 2> /dev/null");
    }

    #
    #  If override gdb binary use that one
    #
    if ( $gdb_bin_override ne "" ) 
    {
	system("cp $gdb_bin_override $local_gdb_path");
    }

    #
    #  If gdb is not already present or a user override then try and locate it.
    #  If gdb is present, then just use the one that is there.
    #
    if ( ! -x $local_gdb_path || $gdb_override ne "" ) 
    {
        install_gdb( $my_dump_path_name, $local_gdb_path, $dumpenv);

        #
        #  If still not present then the install_gdb() function
        #  could not locate which gdb to use.
        #
        if ( ! -x $local_gdb_path ) 
        {
            die "Unable to locate GDB executable";
        }
    }
    else
    {
        printf "Found GDB:\t\t$local_gdb_path\n" if $debug;
    }

    #
    #  We need to check for RETAIL dumps.  If this is retail dump then we need to 
    #  copy over some files before we can continue or evildump will not find
    #  "gdb", the flare macros, or the Dart .so binary if this is a Dart dump.
    #
    if (  ( ( "$my_dump_path_name" =~ /(C4Core)/ ) || 
            ( "$my_dump_path_name" =~ /(_admin)/ ) ) &&
            ( "$my_dump_path_name" =~ /(RETAIL)/ ) )
    {
        my $num = get_build_num( $my_dump_path_name );
        my $branch_name = get_branch_name( $my_dump_path_name );

        my $real_path = "/c4shares/re/Results/c4build/*/*$branch_name*$num*/*RET*/Dist/rpm*";
        print "DEBUG: real_path: $real_path\n" if $debug;

        open FTP_LOC_PIPE, "grep FTP $real_path |" or die "can't open grep pipe";

        my $path;
        while (<FTP_LOC_PIPE>) 
        {
            next if (! /c4core/);

            chomp;

            s/^\s*//;
            ($floc, $path) = split(/\s+/);

            $path =~ s#^file://##;
            $path =~ s/\/Dist\/$/\/Debug\//;

            print "DEBUG: path is $path\n" if $debug;
            if ( -e "$path" )
            {
                print "Found C4Core path for bundle $num:  $path\n";

                if ( ! ( -e "$my_dump_path/EMC/C4Core" ) )
                {
                    print "$my_dump_path/EMC/C4Core does not exist in the current path!  Check that the binaries file was expanded.\n\n";
                    exit;
                }

                if ( ! ( -d "$my_dump_path/EMC/C4Core/lib/gdb_macros" )  )
                {
                    printf("Creating gdb_macros directory for macro files\n");
                    system("chmod -R a+w . 2> /dev/null");
                    system("mkdir -p $my_dump_path/EMC/C4Core/lib/gdb_macros") and die "Cannot create $my_dump_path/EMC/C4Core/lib/gdb_macros directory\n";
                }
                
                print "Copying C4Core .so files for bundle $num to $my_dump_path/EMC/C4Core/lib/gdb_macros. \n\n";

                #system("ls " . $path);
                system("cp -v $path/*.so $my_dump_path/EMC/C4Core/lib/gdb_macros");

                my $dart_path = "$my_dump_path/EMC/C4Core/bin/cdx.so"; 
                my $new_dart_path = "$my_dump_path/EMC/C4Core/bin/cdx.so.orig"; 

                #  
                #  Fix the dart .so file's location. 
                #
                if ( -e "$dart_path" )
                {
                    print "Copying Debug Dart cdx.so files for bundle $num to $my_dump_path/EMC/C4Core/bin. \n\n";
                    system("mv -v $dart_path $new_dart_path");
                    system("mv -v $my_dump_path/EMC/C4Core/lib/gdb_macros/cdx_dbg.so $dart_path");
                }

        }
            close FTP_LOC_PIPE;
            break;
        }   
    }

    if ( "$my_dump_path_name" =~ /_(safe)/ )
    {
        $gdb_path = "$my_dump_path/usr/bin/gdb";
        $ic_path = "./EMC/csx/ubin".ELFxx($my_dump_path_name)."/csx_ic_std.x";
    }
    elsif ( "$my_dump_path_name" =~ /(RemoteAgent)/ )
    {
        $gdb_path = "$my_dump_path/usr/bin/gdb";
        $ic_path = "$my_dump_path/opt/safe/safe_binaries/user/exec/RemoteAgent.exe";
    }
    elsif ( "$my_dump_path_name" =~ /(NDU)/ )
    {
        $gdb_path = "$my_dump_path/usr/bin/gdb";
        $ic_path = "$my_dump_path/opt/safe/safe_binaries/user/exec/NDU.exe";
    }
    elsif ( "$my_dump_path_name" =~ /(newSP)/ )
    {
        $gdb_path = "$my_dump_path/usr/bin/gdb";
        $ic_path = "$my_dump_path/opt/safe/safe_binaries/user/exec/newSP.exe";
    }
    elsif ( "$my_dump_path_name" =~ /(AdminTes)/ )
    {
        $gdb_path = "$my_dump_path/usr/bin/gdb";
        $ic_path = "$my_dump_path/opt/safe/safe_binaries/user/exec/AdminTest.exe";
    }
    #
    #   This is the Morpheus version of fbecli.
    #
    elsif ( "$my_dump_path_name" =~ /(fbecli_)/ )
    {
        $gdb_path = "$my_dump_path/usr/bin/gdb";
        $ic_path = "$my_dump_path/opt/safe/safe_binaries/user/exec/fbecli.exe";
    }
    elsif ( "$my_dump_path_name" =~ /(mnsvcd)/ )
    {
        $gdb_path = "$my_dump_path/usr/bin/gdb";
        $ic_path = "$my_dump_path/EMC/MNSVC/bin/mnsvcd";
    }
    elsif ( "$my_dump_path_name" =~ /(clariiontool)/ )
    {
        $gdb_path = "$my_dump_path/usr/bin/gdb";
        $ic_path = "$my_dump_path/EMC/CEM/bin/clariiontool/clariiontool";
    }
    elsif ( "$my_dump_path_name" =~ /(psmtool_)/ )
    {
        $gdb_path = "$my_dump_path/usr/bin/gdb";
        $ic_path = "$my_dump_path/opt/safe/safe_binaries/user/exec/psmtool.exe";
    }
    elsif ( "$my_dump_path_name" =~ /(TLD)/ )
    {
        $gdb_path = "$my_dump_path/usr/bin/gdb";
        $ic_path = "$my_dump_path/opt/safe/safe_binaries/user/exec/TLDlistener.exe";
    }
    elsif ( "$my_dump_path_name" =~ /(umpsSend)/ )
    {
        $gdb_path = "$my_dump_path/usr/bin/gdb";
        $ic_path = "$my_dump_path/opt/safe/safe_binaries/user/exec/umpsSend.exe";
    }
    elsif ( "$my_dump_path_name" =~ /(MluCli)/ )
    {
        $gdb_path = "$my_dump_path/usr/bin/gdb";
        $ic_path = "$my_dump_path/opt/safe/safe_binaries/user/exec/MluCli.exe";
    }
    elsif ( "$my_dump_path_name" =~ /(PEServ)/ )
    {
        $gdb_path = "$my_dump_path/usr/bin/gdb";
        $ic_path = "$my_dump_path/opt/safe/safe_binaries/user/exec/PEService.exe";
    }
    elsif ( "$my_dump_path_name" =~ /(sedcli)/ )
    {
        $gdb_path = "$my_dump_path/usr/bin/gdb";
        $ic_path = "$my_dump_path/opt/safe/safe_binaries/user/exec/sedcli.exe";
    }
    elsif ( "$my_dump_path_name" =~ /(KdbmTool)/ )
    {
        $gdb_path = "$my_dump_path/usr/bin/gdb";
        $ic_path = "$my_dump_path/opt/safe/safe_binaries/user/exec/KdbmTool.exe";
    }
    elsif ( "$my_dump_path_name" =~ /(gms_svr)/ )
    {
        $gdb_path = "$my_dump_path/usr/bin/gdb";
        $ic_path = "./EMC/csx/ubin".ELFxx($my_dump_path_name)."/csx_ic_std.x";
    }
    elsif ( "$my_dump_path_name" =~ /(rt_collector)/ )
    {
        $gdb_path = "$my_dump_path/usr/bin/gdb";
        $ic_path = "$my_dump_path/opt/observability-consumer/bin/rt_collector";
    }
    elsif ( "$my_dump_path_name" =~ /(crmd)/ )
    {
        $gdb_path = "$my_dump_path/usr/bin/gdb";
        $ic_path = "$my_dump_path/usr/lib64/pacemaker/crmd";
    }
    elsif ( "$my_dump_path_name" =~ /(obs_hist)/ )
    {
        $gdb_path = "$my_dump_path/usr/bin/gdb";
        $ic_path = "$my_dump_path/opt/observability-consumer/bin/obs_hist_collector";
    }
    elsif ( "$my_dump_path_name" =~ /(safe).*(cdxic)/ )
    {
        $gdb_path = "$my_dump_path/usr/bin/gdb";
        $ic_path = "./EMC/csx/ubin".ELFxx($my_dump_path_name)."/csx_ic_std.x";
    }
    elsif ( "$my_dump_path_name" =~ /(C4Core)/ )
    {
        $gdb_path = "$my_dump_path/EMC/csx/ubin64/gdb";
        $ic_path = "./EMC/csx/ubin".ELFxx($my_dump_path_name)."/csx_ic_std.x";
    }
    elsif ( "$my_dump_path_name" =~ /(_admin)/ )
    {
        $gdb_path = "$my_dump_path/EMC/csx/ubin64/gdb";
        $ic_path = "./EMC/csx/ubin".ELFxx($my_dump_path_name)."/csx_ic_std.x";
    }
    elsif ( "$my_dump_path_name" =~ /(logDaemon)/ )
    {
#
#       Use native GDB for logDaemon.
#
        $gdb_path = "gdb";
        $ic_path = "EMC/c4_logging/logging/logDaemon.x";
    }
    elsif ( "$my_dump_path_name" =~ /(ECOM)/ )
    {
#
#       Control Path ECOM cores.
#
        $gdb_path = "$my_dump_path/usr/bin/gdb";
        $ic_path = "./EMC/CEM/bin/system/ECOM";
    }
    elsif ( "$my_dump_path_name" =~ /(mgmtd)/ )
    {
#
#       Control Path ECOM cores.
#
        $gdb_path = "$my_dump_path/usr/bin/gdb";
        $ic_path = "./nas/sbin/mgmtd";
    }
    else
    {
        printf "ERROR:Binary file path location not set up in evildump script.\n";
        printf "Note:This is based on the dump name, so be sure it has _safe or other keyword in the name.\n";
    }
    

    my $my_dump_name = `/usr/bin/basename $my_dump_path_name`;
    chomp $my_dump_name;

    if ( -e "$home/.gdbinit" )
    {
        print "Found .gdbinit file in your home directory.  Relocating file to ~/.gdbinit_relocate\n";
        system("mv $home/.gdbinit $home/.gdbinit_relocate");
    }

    my $gdb_command;
    my $orig_source_path = "no_orig_source_path";
    my $COMMAND_FILE;

    if (  "$my_source_path" !~ /no_source/ )
    {
#
#  We need to determine what the source path is in the symbols so we can
#  substitute ours in its place.
#

        open ( $COMMAND_FILE, "> ./.cmd_file ") || die "Cannot open ./.cmd_file";
        print $COMMAND_FILE <<EOF
set solib-absolute-prefix $my_lib_prefix
file $ic_path
core-file $my_dump_name
info sources
quit
EOF
;        
        close ( $COMMAND_FILE );

        $gdb_command = "$gdb_path -cd=$my_dump_path -q -x ./.cmd_file -batch | grep -m 10 $branch";
	print "Running GDB command: $gdb_command \n" if $debug;
        
        my $sub_name;

        open (GDB_OUTPUT, "$gdb_command |");
        
        while (<GDB_OUTPUT>)
        {
            chomp;
            if ( $_ =~ /([\w\/]+?\/$branch)/ )
            {
                $orig_source_path = $1;
                print "Original Source path = $orig_source_path\n" if $debug;
                break;
            }
        }
        close ( GDB_OUTPUT );
   }

   require "syscall.ph";
   if (syscall(&SYS_futex, 0xffffffff, (128|1), 0, 0, 0) == -1 and $!{ENOSYS}) {
       print STDERR q{
/-------------------------------------------------------------------\
| WARNING: Your running kernel does not include support for private |
|          futexes.  You may receive an error while debugging.      |};
        if (-e "/re/bin/update_vm") {
            print STDERR q{
|          You may run the following command to update your VM:     |
|              sudo /re/bin/update_vm                               |};
        }
        print STDERR q{
\-------------------------------------------------------------------/

};
    }

    #
    #  Early Neo VNXe Non-KittyHawk RETAIL cores have support for an older gdb.  So we need to
    #  special case the gdbinit setting we do for CCSX cores since newer gdbinit setting do not
    #  work in the older gdb versions.
    #
    if (  ( ( "$my_dump_path_name" =~ /(C4Core)/ ) ||
            ( "$my_dump_path_name" =~ /(_admin)/ ) ) &&
            ( "$my_dump_path_name" =~ /(RETAIL)/ ) )
    {
    open ( $COMMAND_FILE, " > /tmp/gdbinit.$$ ") || die "Cannot open /tmp/gdbinit.$$";
    print $COMMAND_FILE <<EOF
set height 0
set solib-absolute-prefix $my_lib_prefix
file $ic_path
core-file $my_dump_name
EOF
;
    }
    #
    #  For all KittyHawk cores ( or later ) uses these gdbint.
    #
    else 
    {
    # check to see if quickbt is supported
    my $quickbt = 0;
    open ($CHECK_FILE, " >/tmp/gdbcheck.$$ ") || die "Cannot open /tmp/gdbcheck.$$";
    print $CHECK_FILE <<EOF
show print quickbt
EOF
;
    my $gdbout = `$gdb_path -q -batch -n -x /tmp/gdbcheck.$$ 2>/dev/null`;
    if ($gdbout =~ /quick/)
    {
        $quickbt = 1;
    }
    system("rm -f /tmp/gdbcheck.$$");
    # end quickbt support check
    print "Personal GDB commands Selected: $opt_f\n" if $opt_f;
    if ( ! -f $opt_f)
    {
    open ( $COMMAND_FILE, " > /tmp/gdbinit.$$ ") || die "Cannot open /tmp/gdbinit.$$";
    print $COMMAND_FILE <<EOF
set height 0
set solib-absolute-prefix $my_lib_prefix
set print thread-events off
set build-id-verbose 0
file $ic_path
core-file $my_dump_name
EOF
;
    }
    else
    {
    print "using personal GDB commands.\n";
    open ( $COMMAND_FILE, " > /tmp/gdbinit.$$ ") || die "Cannot open /tmp/gdbinit.$$";
    print $COMMAND_FILE <<EOF
set height 0
set solib-absolute-prefix $my_lib_prefix
set print thread-events off
set build-id-verbose 0
file $ic_path
core-file $my_dump_name
source -s -v $opt_f
EOF
;
    }
    if ($quickbt == 1)
    {
    print $COMMAND_FILE <<EOF
define qbtall
set print address 0
set print quickbt 1
thread apply all where
set print quickbt 0
set print address 1
set \$rsp = \$rsp
end
echo !!!!Use qbtall to create a quick backtraces of all threads\\n
echo !!!!See help for qbtall\\n
document qbtall
qbtall
 Do a thread trace of all stacks in a quick format without file
 and line numbers
end
EOF
;
    }
    }
   
    if ( $orig_source_path !~ /no_orig_source_path/  and  $my_source_path !~ /no_source/ )
    {
        print $COMMAND_FILE "set substitute-path $orig_source_path $my_source_path\n\n";
    }

    close ( $COMMAND_FILE );

    system("chmod a+wrx /tmp/gdbinit.$$ 2> /dev/null");
    if($using_ddd)
    {
        $gdb_command = "/usr/bin/ddd -debugger $gdb_path -cd=$my_dump_path -x /tmp/gdbinit.$$";
    }
    else
    {
        $gdb_command = "$gdb_path -cd=$my_dump_path -x /tmp/gdbinit.$$";
    }
    
    print "Launch GDB as:\t\t$gdb_command\n";
    print "/tmp/gdbinit.$$ contents:\n" if $debug;
    system("nl /tmp/gdbinit.$$\n") if $debug;
    print "\n";

    system($gdb_command);

    if ( -e "$home/.gdbinit_relocate" )
    {
        system("mv $home/.gdbinit_relocate $home/.gdbinit");
    }

    return;

}

    #
    # main
    #

    $ed_opts = "Dchb:a:d:ef:i:z:s:g:G:";

#massage_options( $ed_opts );

    getopts( $ed_opts );

#$opt_d = $custom_dir; # Using the Directory parsed from massage_options

    if ( $opt_h )
    {
        print $usage;
        exit;
    }

    if ( $opt_d eq "." )
    {
         open (CD_OUTPUT, "cd |");
         while (<CD_OUTPUT>)
         {
             chomp;
             next if "";
             $opt_d = $_;
         }
         close CD_OUTPUT;
    }
    #
    # We need a raw defect number, the -i option, or the -z option
    # to find the target.
    #
 
    if ( ! ( $opt_d || $opt_i || $opt_z ) )
    {
        print "Must use at least -d, -i, or -z\n";
        print $usage;
        exit;
    }
 
    #
    # We can't have multiple targets.  Only allow one of the following:
    # raw defect number, the -i option, or the -z option.
    #
 
    if ( ( ( $opt_i && $opt_z ) ||
           ( $opt_i && $opt_d ) ||
           ( $opt_d && $opt_z ) ) )
    {
        print "Must use only one of -d, -i, -z, or <defect>\n";
        print $usage;
        exit;
    }
 
    $directory        = $opt_d;
    $dump_path_name   = $opt_z;
    $debug            = $opt_e;
    
    if ( $opt_f )
    {
        if ( ! -f $opt_f )
        {
            print "GDB Personal command file $opt_f does not exit\n";
            print $usage;
            exit;
        }
    }
    
    if ( $opt_i )
    {
        $dir_name =  $opt_i;
    }
    else
    {
        if ( $opt_c || $opt_a)
        {
            print "Must use -c and/or -a with -i. \n";
            print $usage;
            exit;
        }

        $dir_name = $ARGV[0];
    }

    if ( $opt_g )
    {
    if ( ! -f $opt_g ) 
    {
        print "GDB RPM file $opt_g does not exit\n";
        print $usage;
        exit;
    }
    else
    {
	# Make sure it's an RPM file
	system("file -Lb $opt_g | grep -q \"^RPM\"");
	if ($?) {
	    print "GDB RPM file $opt_g is not an RPM file\n";
	    print $usage;
	    exit;
	}	    
    }
    $gdb_override = $opt_g;
    }

    if ( $opt_G )
    {
	if ( ! -x $opt_G ) 
	{
	    print "GDB binary file $opt_G does not exit or is not executable\n";
	    print $usage;
	    exit;
	}
	$gdb_bin_override = $opt_G;
    }

    print "arg_list: $arg_list\n" if $debug;
 
    print "Debug enabled\n" if $debug;
    print "Directory Selected: $directory\n" if $debug;
    print "Defect Selected:    $dir_name\n" if $debug;
    print "Dump Path Selected: $dump_path_name\n" if $debug;
    print "Source Path:        $opt_s\n" if $debug;
    print "GDB override:       $gdb_override\n" if $debug;
    print "GDB binary override:$gdb_bin_override\n" if $debug;
    print "Personal GDB commands Selected: $opt_f\n" if $debug;
    print "\n" if $debug;

    # 
    #   Check for . and ..
    # 
    if ( ( "$dir_name" =~ m/^\.\./ )  || 
         ( "$dir_name" =~ m/^\./ ) )
    {
        print "\"$dir_name\" as a defect name is not valid.\n\n";
        exit
    }

    if ( $opt_z && ! (-f $opt_z ) )
    {
        print "Reminder: -z option must be used on a file\n";
        exit;
    }
 
    if ( $opt_d && ! (-d $opt_d ) )
    {
        print "Reminder: -d option must be used on a directory\n";
        exit;
    }
 
    if ( $opt_b )
    {
        $branch = $opt_b;
    }

    if ( !$directory && !$dump_path_name )
    {
        @search_order = ( rtp_eng, rtp_eng2, sobo_eng );

        if  ( $opt_c )
        {
            print "Adding customer /disk shares to search\n";
            push @search_order, customer;
            push @search_order, customer2;
        }

        if ( $opt_a )
        {
            print "Adding $opt_a share to search as Custom_Dir\n";
            $locations{"Custom_Dir"} = { "$opt_a" => 1 };
            push @search_order, Custom_Dir;
        }
 
        #
        # See if we can find any directories that match our qualifications.
        #

        for $location ( @search_order )
        {
            print "Checking search order entry $location\n" ;

            for $dump_dir ( keys %{ $locations{ $location } } )
            {
                #
                # find_dir() will fill up directory_candidates as a side effect.
                #

                if ( ! -d $dump_dir )
                {
                    printf "$dump_dir in search order NOT found.  Skipping.\n";
                    next;
                }

                if( !$directory )
                {
                    print "\nRoot find_dir on $dump_dir\n" if $debug;

                    $directory = find_dir( $dump_dir,
                                           $dir_name,
                                           $locations{ $location }{ $dump_dir } );
                }

                last if( $directory );
             }
          }

          print "\n";

      if ( !$directory && @directory_candidates )
      {
         print "Found multiple directories\n";

         for $directory_candidate ( @directory_candidates )
         {
            print "    $directory_candidate\n";
         }
         print "\n";

         exit;
      }
      elsif ( !$directory )
      {
	 $directory = `whereisAR $dir_name|grep /`;
	 chomp $directory;
	 if (! (-d $directory)) {
           print "Cannot find dump directory $directory\n";
           exit;
         }
      }

   }
   if ( -d "$directory" )
   {
      print "Found directory:\t";
      print "$directory\n";

      find (\&find_files, "$directory");

      # Run find_files again in case there is a .gz dump inside a .tar
      find (\&find_files, "$directory");

      find (\&determine_dump_files, "$directory");

   }
   elsif ( !$dump_path_name )
   {
      print "$directory not a valid directory\n";

      exit;
   }

   #
   # Found other dump files and zip archives in this directory.
   #

   if ( @dump_pretty_path_candidates )
   {
      print "Found dumps:\t\t";
      for $dump_path_candidate ( @dump_pretty_path_candidates )
      {
         print "$dump_path_candidate\n";
         push @dump_path_candidates, $dump_path_candidate;
      }

      #
      # If there is only one dump found, then go ahead and put our faith in
      # the fact that this dump is the one we are looking for.
      #

      if ( scalar( @dump_path_candidates ) == 1 )
      {
         $dump_path_name = @dump_path_candidates[ 0 ];
      }
   }

   print "\n";

   #
   # If they gave us just a dump file name, let's figure out the root path
   # to that dump.
   #

   if ( $opt_z )
   {
      if ( $directory || !$dump_path_name )
      {
         print "Internal error\n";
         exit;
      }

      @dump_path_name_components = split /\//,$dump_path_name;

      $num_dump_path_comps = scalar @dump_path_name_components;

      if ( $num_dump_path_comps == 1 )
      {
         $directory = ".";
      }
      else
      {
         for $dump_path_name_component ( @dump_path_name_components )
         {
            if ( --$num_dump_path_comps )
            {
               $directory = $directory ?
                                    "$directory/$dump_path_name_component" :
                                    "$dump_path_name_component";

            }
         }
      }
   }

   #
   # Figure out the log file in case we need it later.
   #

   if ( $directory )
   {
      $logfile = "$directory/EvilDumpSummary.txt";
   }
   else
   {
      print "Internal error - No directory found!";
      exit;
   }

    #
    # If this is an ECOM core, try to unpack all the symbols
    #
    if ( $dump_path_name =~ /CP_.*ECOM/)
    {
       print "Going to try unpacking the ECOM symbols... ";
 
       # Check if we have a symbols file unpacked in our directory
       my $rc = system("/bin/ls $directory/EMC/CEM/bin/cem_symbols*.sh >/dev/null 2>/dev/null");
       if ( $rc == 0 )
       {
          print "Found them... Unpacking... ";
       }
 
       # Do the actual unpacking of the symbols
       my $rc = system("$directory/EMC/CEM/bin/cem_symbols*.sh --force ALL $directory/EMC/CEM >/dev/null 2>/dev/null             ");
       if ( $rc == 0 )
       {
          print "Success!\n\n";
       }
       else
       {
          print "FAILED\n\n";
       }
 
    }

   #
   # Start up c4gdb
   #

   if ( -f $dump_path_name )
   {
      if ( $opt_s ) 
      {
          start_gdb( $dump_path_name, $opt_s, $opt_D );
      }
      else
      {
          start_gdb( $dump_path_name, "no_source", $opt_D );
      }
   }
   elsif ( scalar ( @dump_path_candidates ) )
   {
      print "$dump_path_candidates\n";
      print "Multiple dump files found, you will have to bust each one with the -z option.\n";
      exit;
   }
   else
   {
      print "No dump file or zip archive found in $directory\n";
      exit;
   }
   exit;

#
#  Used if --help is specified.
#
sub main::HELP_MESSAGE()
{
    print $usage;
}

