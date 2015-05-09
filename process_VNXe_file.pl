#!/usr/bin/perl
###################################################
# This Perl script is a work in progress and it is
# used to process VNXe customer files.
# It is used to decompress tar/zip/gz files and
# Do automated searches of log files for significant
# VNXe events.
# Please send feedback enhancement requests to 
# kenneth.wood@emc.com
###################################################
# The most common issues are 
# 1) Some failure that results in one or more sp reboots
#    - It would be real nice if script could find/hightlight causes
# 2) Some failure to create/delete a storege resource
#    - The script should highlight all create/deletes
# 3) Inability to connect - Ussually network issues
# 4) Failures to upgrade.


# TODO
# Plugin for ARs
# AR419928
# Iscsi initiator check from svc_storage_check
# These don't match:
# Connected Initiators:
# iqn.1991-05.com.microsoft:paraguay.csw.alewife.net
# server_iscsi -mask -list
# iqn.1991-05.com.microsoft.paraguay.csw.alewife.net 1 

# TODO
# Check file time and throw away file if too old

use strict;
use Data::Dumper qw(Dumper); 
use Time::Local;
use Getopt::Long;
use Cwd;
use File::Basename;

my $ARTF_PATH = "";
my $TERM_FILE = "";
my $MERGE     = 0;
my $VERBOSE   = 0;
my $SUPRESS   = 0;
my $SEARCH    = 0;
my $DECOMP    = 0;
my $LEVEL     = 0;
my $ALLTIME   = 0;
my $TIME      = 10;
my $lastime   = 0;
my $ONESTEP   = 0;
my $BAM_NEW   = 0;
my $CONFIG    = 0;
my $NETWORK   = 0;
my $NW_CONFIG = 0;
my $SVC_STOR  = "";
my $SVC_NW    = "";
my $KNOWN_ARS = 0;
my @OUTPUT;
my %TERMS;
#my %TERMS = (  test_filename => { terms => { term1 => 1, term2 => 2, term3 => 3, term4 => 4},
#                                 filters => { filter1 => 1, filter2 => 2} } );

# Some logs need this: 
my $GMT_to_local_offset = (60 * 60 * 4);
my $SPA_ktrace_offset = 0;
my $SPB_ktrace_offset = 0;

# Used to manually offset ktrace. Should be 0
my $fudge_factor = 0;

GetOptions
(
    'vb'       => \$VERBOSE,
    'cf'       => \$CONFIG,
    'sp'       => \$SUPRESS,
    'one'      => \$ONESTEP,
    'bam'      => \$BAM_NEW,
    'alltime'  => \$ALLTIME,
    'terms=s'  => \$TERM_FILE,
    'merge'    => \$MERGE,
    'time=i'   => \$TIME,
    'decomp'   => \$DECOMP,
    'level=i'  => \$LEVEL,
    'nw'       => \$NETWORK,
    'nwc'      => \$NW_CONFIG,
    'ars'      => \$KNOWN_ARS,
    'path=s'   => \$ARTF_PATH
) or usage();

print_vb("Go back $TIME days\n");
$TIME = (60*60*24*$TIME);

$LEVEL = 1 if( !$LEVEL && ($NW_CONFIG || $NETWORK || $CONFIG));

if ( !$DECOMP || $BAM_NEW )
{
    $SEARCH = 1;
}

if ( !$ARTF_PATH )
{
    print "Please provide path\n";
    usage();
}

if ( $MERGE )
{
    $LEVEL = 6;
}

if ( $LEVEL == 6 )
{
    $SUPRESS = 1;
}

if ( $ONESTEP )
{
    $DECOMP  = 1;
    $SEARCH  = 1;
    $SUPRESS = 1;
    $LEVEL   = 4 if (!$LEVEL);
}

if ( !$DECOMP && !$LEVEL && !$KNOWN_ARS )
{
    print "Please use either decomp or level $DECOMP $LEVEL\n";
    usage();
}

sub usage 
{
    print("process_NX3e_file -path <path> -level <search_level> -decomp -terms <custom_term_file> -merge -vb -sp\n");
    print("    -path       Path to where the data_collection logs are or a set of both spa and spb logs\n");
    print("    -decomp     Will decompress all files in data_collection. Search is a separate step\n");
    print("    -level      Custom search levels, 1-5 (5 gives most info)\n");
    print("    -level 6    Rather than selective search, mearge all logs defined in vnxe_searchterms(takes a while)\n");
#TODO    print("    -bam        Match all BAM NEW requests/responses\n");
    print("    -nw         Use network search terms only\n");
    print("    -terms      Use custom search term file instead of default\n");
    print("    -time       Specify filter for numbers of days (search back n days)\n");
    print("    -merge      Merge all entries in log files defined in vnxe_merge_files into one file\n");
    print("    -vb         Verbose debugging in parsing script\n");
    print("    -sp         Supress most screen output (use file debug_output_xxxx )\n");
    print("    -nwc        Display VNXe network config\n");
    print("    -cf         Display VNXe storage config\n");
    exit 1;
}

if ( $DECOMP )
{
    decompress();
}
 
get_config_path();
if ( $CONFIG )
{
    show_config();
    exit 0;
}

if ( $NW_CONFIG )
{
    show_network();
    exit 0;
}

if ( $KNOWN_ARS )
{
    match_ars();
    exit 0;
}

if ( $SEARCH )
{
    load_search_terms();
    print Dumper \%TERMS if ( $VERBOSE );
    search_logs();
}

exit 0;

sub load_search_terms
{
    my @std_terms;
    my @custom_terms;

    if ( $BAM_NEW )
    {
        my $nx_filename   = "cemtracer.log";
        my $nx_level      = "1";
        my @bam_terms = ( '"BAMTask timeout"',
                          '"BAMTask xmlns"',
                          '"bam:"');

        foreach my $nx_searchterm ( @bam_terms )
        {
            my %nx_searchterms = ($nx_searchterm =>$nx_level);
            if (exists $TERMS{$nx_filename})
            {
                print_vb("MOD: fn $nx_filename term $nx_searchterm lvl $nx_level\n");
                $TERMS{$nx_filename}{'terms'}->{$nx_searchterm} = $nx_level;
            }
            else
            {
                $TERMS{$nx_filename} = { terms => \%nx_searchterms};
                print_vb("ADD: fn $nx_filename term $nx_searchterm lvl $nx_level\n");
            }
        }
        return;
    }

    if ( $TERM_FILE )
    {
        print "Loading Custom Search\n";
        my $filename = $TERM_FILE;
        open(FP, "$filename") || die ("Unable to open search term file $filename\n");
        @custom_terms=<FP>;
        close(FP);
    }

    my $filename;
    if ( $NETWORK )
    {
       print "Loading Network Search\n";
       $filename = "vnxe_networkterms";
    }
    elsif (!$TERM_FILE)
    {
        if ( $LEVEL == 6 )
        {
            $filename = "vnxe_merge_files";
            print "Merging entire log files (defined in $filename)\n";
        }
        else
        {
            print "Loading level $LEVEL Standard Search\n";
            $filename = "vnxe_searchterms";
        }
    }

    if ( !$TERM_FILE || $MERGE )
    { 
        open(FP, "$filename") || die ("Unable to open search term file $filename\n");
        @std_terms=<FP>;
        close(FP);
    }
    my @all_data = (@custom_terms, @std_terms); 
    my $alld = join('',@all_data);
    print_vb("Loading\n");

    for my $line (@all_data)
    {
        chomp($line);
        my $comment_line = substr($line,0,1);
        if ( $comment_line eq '#' )
        {
             print_vb("Skipping line [$line]\n");
        }
        else
        {
             my @chunks        = split(',', $line);
             my $nx_filename   = $chunks[0];
             my $nx_searchterm = $chunks[1];
             chomp($nx_searchterm);
             $nx_searchterm    =~ s/^\s+//;
             my $nx_level      = $chunks[2];
             chomp($nx_level);
             $nx_level =~ s/^\s+//;
             if (exists $TERMS{$nx_filename})
             {
                 if ( $nx_level eq 'filter' )
                 {
                     print_vb("MOD: fn $nx_filename filter $nx_searchterm \n");
                     $TERMS{$nx_filename}{'filters'}->{$nx_searchterm} = $nx_level;
                 }
                 else
                 {
                     print_vb("MOD: fn $nx_filename term $nx_searchterm lvl $nx_level\n");
                     $TERMS{$nx_filename}{'terms'}->{$nx_searchterm} = $nx_level;
                 }
             }
             else
             {
                 my %nx_searchterms = ($nx_searchterm =>$nx_level);
                 if ( $nx_level eq 'filter' )
                 {
                     print_vb("ADD: fn $nx_filename filter $nx_searchterm \n");
                     $TERMS{$nx_filename} = { filters => \%nx_searchterms};
                 }
                 else
                 {
                     print_vb("ADD: fn $nx_filename term $nx_searchterm lvl $nx_level\n");
                     $TERMS{$nx_filename} = { terms => \%nx_searchterms};
                     if ( $nx_filename eq "c4_ccsx_ktrace.log" )
                     {
                         $TERMS{$nx_filename}{'terms'}->{"DATE:"} = 1;
                     }
                 }

#                 foreach my $key (keys %{$TERMS{$nx_filename}{'terms'}})
#                 {
#                     my $level = $TERMS{$nx_filename}{'terms'}->{$key};
#                     print("term: $key level: $level\n");
#                 }
            }
        }
    }
}

sub print_logs
{
    my @sortorder = sort keys %TERMS;
    foreach my $name_key (@sortorder)
    {
        # Exclude boot log dir
        my @files=`find $ARTF_PATH -name $name_key* | grep -v boot`;
        my $cnt = scalar(@files);
        print("Key: $name_key cnt: $cnt\n");
    }
}

sub file_to_sp
{
    my $filename = shift;
    my $SP = "";
    if ( $filename =~ m/\/spa_/ )
    {
        $SP = "SPA\t";
    }
    elsif ( $filename =~ m/\/spb_/ )
    {
        $SP = "SPB\t";
    }
    elsif ( $filename =~ m/\/spa/ )
    {
        $SP = "SPA\t";
    }
    elsif ( $filename =~ m/\/spb/ )
    {
        $SP = "SPB\t";
    }
    else
    {
        print("Unable to discern spa/spb logs [ $filename ]\n");
        exit 1;
    }
    return $SP;
}

sub search_logs
{
    calc_ktrace_offsets();
    calc_cdxic_offsets();
    print_vb("Searching\n");
    my @sortorder = sort keys %TERMS;
    foreach my $name_key (@sortorder)
    {
        # Exclude boot log dir
        print "[$ARTF_PATH] [$name_key]\n";
        my @files=`find $ARTF_PATH -name $name_key* | grep -v boot`;
        my $cnt = scalar(@files);
        print_vb("Key: $name_key cnt: $cnt\n");
        if ( $name_key eq "test_filename" )
        {
             next;
        }
        foreach my $filename (@files)
        {
            my $allterms = "";
            my $SP = file_to_sp($filename);
            chomp($filename);
            print_vb("File: $filename\n");
            # We don't add the filters here because it changes the format of grep output
            foreach my $term_key (keys %{$TERMS{$name_key}{'terms'}})
            {
                my $level = $TERMS{$name_key}{'terms'}->{$term_key};
                $allterms = $allterms . " -e $term_key" if ( $level <= $LEVEL ); 
            }

            next if ( !$allterms );
            my @grep_lines;
            if ( $LEVEL == 6 )
            {
                print("merging $filename\n");
                open(FP, "$filename") || die ("Unable to open svc_network file $SVC_STOR\n");
                @grep_lines=<FP>;
            }
            else
            {
                print_vb("fgrep $allterms $filename\n");
                @grep_lines=`grep $allterms $filename`;
            }
            my $count = scalar(@grep_lines);
            if( ($count == 1) && ($grep_lines[0] =~ "Binary file") )
            {
                print_sp("Skipping: $grep_lines[0]\n");
            }
            elsif ($count)
            {
                my $timeoffset = 0;
                print_vb("Found $count entries in $filename with $allterms\n");
                if ( $filename =~ "ktrace" )
                {
                    if ( $filename =~ "spa_" )
                    {
                        $timeoffset = $SPA_ktrace_offset;
                    }
                    else
                    {
                        $timeoffset = $SPB_ktrace_offset;
                    }
                }
                my $last_time = 0;
                foreach my $grep_line (@grep_lines)
                {
                    # Now that we have the list filter the results
                    my $skipit = 0;
                    foreach my $filter_key (keys %{$TERMS{$name_key}{'filters'}})
                    {
                        my @chunks = split('"', $filter_key);
                        $filter_key = $chunks[1];
                        $skipit = 1 if ( $grep_line =~ $filter_key );
                    }
                    print_vb(".") if ($LEVEL == 6);
                    my $standard_time = gettime($grep_line);
                    if((( $standard_time == -1 ) && !$last_time) || $skipit )
                    {
                        print_vb("Skipping: $grep_line\n");
                    }
# TODO move this to term file under filter
                    elsif( ( $grep_line !~ "DATE:" ) && 
                           ( $grep_line !~ "ha_alive" ) && 
                           ( $grep_line !~ "PEER_ASYNC_READY" ) )
                    {
                        if( $standard_time == -1 )
                        {
                           $standard_time = ($last_time + 1);
                        }
                        else
                        {
                            $standard_time += $timeoffset;
                        }
                        chomp($grep_line);
                        if ( !$ALLTIME && ( ($lastime - $standard_time) > $TIME ))
                        {
                            next;
                        }

# TODO I wish we could tag high severity issues in log
                        my $str = "$standard_time $SP $grep_line\n";
                        if ( $LEVEL == 6 )
                        { 
                            push(@OUTPUT,"$str");
                        }
                        else
                        {
# Why doesn't his work?
#                          if ( grep(/$str/,@OUTPUT) )
                            my $foundit = 0;
                            foreach my $tline (@OUTPUT)
                            {
                                if ( $tline eq $str )
                                {
                                    $foundit = 1;
                                }
                            }
                        
                            if ( !$foundit )
                            {
                                push(@OUTPUT,"$str");
                            }
                        }
                    }
                }
            }
        }
    } 
    process_dmi_log();
    print("-----------------DEBUG_OUTPUT------------------\n");
 
    @OUTPUT = sort(@OUTPUT);
    my $str_dir=getcwd;
    my @chunks = split('/',$ARTF_PATH);
    my $cnt = scalar(@chunks);
    my $filename= "$str_dir" . "/$ARTF_PATH" . "/debug_output_lvl" . "$LEVEL". "_";

    if ( $NETWORK )
    {
        $filename = $filename . "nw_";
    } 
    $filename = $filename . "@chunks[$cnt - 1]";

    system("rm -f $filename");

    my $buf = join('',@OUTPUT);
    open FP, ">>$filename";
# Required for Health script which calls this
    print_sp("$buf\n");
    print FP "$buf\n";
    close FP;
    if( $GMT_to_local_offset )
    {
    print("-----------------GMT_to_local_offset: $GMT_to_local_offset\n");
    }
    if( $SPA_ktrace_offset || $SPB_ktrace_offset )
    {
    print("-----------------SPA ktrace offset:   $SPA_ktrace_offset\n");
    print("-----------------SPB ktrace offset:   $SPB_ktrace_offset\n");
    }
    #
    #
    if ($SVC_STOR)
    {
        print("$SVC_STOR");
    }
    print_image_rev();
    match_ars() if( $LEVEL != 6 );
    print("Debug output: $filename\n");
}

sub process_dmi_log
{
    my @files=`find $ARTF_PATH -name sptool_-d_-l.txt`;
    foreach my $filename (@files)
    {
        my $SP = file_to_sp($filename);
        open(FP, "$filename") || die ("Unable to open dmi log file: $filename\n");
        my @storage_config=<FP>;
        close(FP);
        my $get_next = 0;
        my $last_line;
        foreach my $line (@storage_config)
        {
            if ($line =~ /Type/)
            {
                $get_next = 1; 
            }
            else
            {
                if( $get_next )
                {
                    chomp($last_line);
                    chomp($line);
                    $line = $last_line . " " . $line;
                    my $standard_time = gettime($line);
                    if( $standard_time == -1 )
                    {
                        print_vb("Skipping: $line\n");
                    } 
                    if( ($lastime - $standard_time) > $TIME )
                    {
                        next;
                    }
                    my $str = "$standard_time $SP DMI $line\n";
                    push(@OUTPUT,"$str");
                }
                $get_next = 0;
            }
            $last_line = $line;
        }
    }
}

sub get_config_path
{
    my @files=`find $ARTF_PATH -name 'svc_storage*'`;
    my $count = scalar(@files);
    print("No svc_storage file found. \n") if( !$count);
    $SVC_STOR = join('',@files) if ($count); 
    @files=`find $ARTF_PATH -name 'svc_networkcheck_--info*'`;
    $count = scalar(@files);
    print("No svc_network file found. \n") if( !$count);
    $SVC_NW = join('',@files) if ($count); 
    open(FP, "$SVC_STOR") || die ("Unable to open svc_storage file: $SVC_STOR\n");
    my @storage_config=<FP>;
    close(FP);
    foreach my $line (@storage_config)
    {
        if ($line =~ /Beginning Run/)
        {
            my @chunks = split(/\[/, $line);
            @chunks = split(/\]/, @chunks[1]);
            $lastime = gettime($chunks[0]);
        }
    }
}

sub decompress
{
    my $count = 1;
    my @completed_files;
    my $strt_dir=getcwd;
    while ( $count )
    {
        $count=0;
        my @files1=`find $ARTF_PATH -name '*.tar'`;
        my @files2=`find $ARTF_PATH -name '*.zip'`;
        my @files3=`find $ARTF_PATH -name '*.tgz'`;
        my @files4=`find $ARTF_PATH -name '*.bz2'`;
        my @files5=`find $ARTF_PATH -name '*.gz'`;
        my @files=(@files1,@files2,@files3,@files4,@files5);
        foreach my $file (@files)
        {
            my %thash;
            @thash{@completed_files}=();
            if ( ! exists $thash{$file} )
            {
                #my ($name,$path,$suffix) = fileparse($file,@suffixlist);
                my $name = basename($file);
                my $path = dirname($file);   
                chdir($path);
                print "Process $file";
                if( $file =~ m/tar$/ )
                {
                    system("tar -xvf $name");
                }
                elsif( $file =~ m/zip$/ )
                {
                    system("unzip -o $name");
                }
                elsif( $file =~ m/tgz$/ )
                {
                    system("tar -zxvf $name");
                }
                elsif( $file =~ m/bz2$/ )
                {
                    system("bzip2 -d $name");
                }
                elsif( $file =~ m/gz$/ )
                {
                    system("gunzip $name");
                }
                chdir($strt_dir);
                push @completed_files, $file;
                $count++;
            }
        }
    }
    $count=scalar(@completed_files);
    print "Completed $count files in $ARTF_PATH\n";
}

my ($gday,$gmon,$gyear,$gepoch);
sub gettime
{
    my ($line,$time_fm) = @_;
    my ($year, $mon, $day, $hr, $min, $sec);
    my %months = (Jan => 1,Feb => 2,Mar => 3,Apr => 4,May => 5,Jun => 6,
                  Jul => 7,Aug => 8,Sep => 9,Oct => 10,Nov => 11,Dec => 12);
    my %days   = (Mon => 1, Tue => 2, Wed => 3, Thu => 4, Fri => 4, Sat => 5, Sun => 6);

# timeformat 
#            11a 2010/05/05-19:36:48.752558    7         5515D940      std:TDD:   Ownership Loss IownLun
#            11b 2010-06-09 00:21:55.955 db:0:3096:E: /nas/bin/nas_diskmark -m -a
#            22a Wed May  5 12:15:06 UTC 2010: Upstart: c4-boot: pre-start completed
#            22b Thu Nov 19 16:09:31 2009 ha-policy.pl: found spb dirty wrt ISCSI_B. Going to reboot spb        
#            33  16 May 2010 23:52:28  - [UIServices] INFO  - {0:3334:350731250}
#            44  May 24 10:30:44 spa crmd: [21102]: WARN: update_failcount: Updating failcount
#            55  slot_3: [05/17/2010 15:03:41] Timed out after 360 seconds
#            60  Type: 90  08-10-2011 07:15:23
#            77  1267186563: DPSVC: 6:  DpInit::taskManagerInit() Done
#            ??  #:U:( 0:1):00000000408e8940:16133:0000000374-100
#            ??  16:31:45.870098          7         5515D940      std:TDD:   Ownership Loss IownLun:1 ExeLast:0 CLARiiONdisk0
#            88  "2011-03-26T12:04:12.471Z" "spa" "C4_logDaemon" "28697" "" "CRIT" "" :: "logPostThread[1]: 
#            98  "1T09:40:07.518Z" "spa" "Neo_CEM" "24500" "Local/admin" "ERROR" "14:160002" :: "System Error: 
#            99  "8T05:19:24.297Z" "spa" "C4_logEventApplication" "10183" "unix/spa/root" "INFO" "" :: "Mar 18 05:19:23 2011 CS_PLATFORM:NASDB"

    my @remove_list = ("Enter password:","server_2 :","server_3 :","server_4 :","server_5 :");
    foreach my $remove (@remove_list)
    {
        if ( $line =~ $remove )
        {
            $line = substr($line,length($remove));
            print_vb("NEWLINE: $line\n");
        }
        else
        {
#            print_vb("[$remove] not found in line [$line]\n");
        }
    }

    print_vb("PROCESS: $line\n");
    my @chunks = split(' ',$line);
    print_vb("0:$chunks[0] 1:$chunks[1] 2:$chunks[2] 3:$chunks[3] 4:$chunks[4] 5:$chunks[5] \n");

    my $char1 = substr($line,4,1);
    my $char2 = substr($line,7,1);
    if (( $char1 eq '/' ) && ( $char2 eq '/' ))
    {
        my @chunks1 = split(/([:,-])/,$line);
        my @chunks2 = split(/\//,$chunks1[0]);
        $year = $chunks2[0];
        $mon  = $chunks2[1];
        $day  = $chunks2[2];
        $hr   = $chunks1[2];
        $min  = $chunks1[4];
        @chunks2 = split(/\./,$chunks1[6]);
        $sec  = $chunks2[0];
#       2010/05/05-19:36:48.752558    7         5515D940      std:TDD:   Ownership Loss IownLun
        print_vb("11a y $year m $mon d $day h $hr m $min s $sec \n");
    }
    elsif (( $char1 eq '-' ) && ( $char2 eq '-' ))
    {
        my @chunks1 = split(/([:,-])/,$line);
        $year = $chunks1[0];
        $mon  = $chunks1[2];
        my @chunks2 = split(' ',$chunks1[4]);
        $day  = $chunks2[0];
        $hr   = $chunks2[1];
        $min  = $chunks1[6];
        my @chunks2 = split(/[.]/,$chunks1[8]);
        $sec  = $chunks2[0];
#       2010-06-09 00:21:55.955 db:0:3096:E: /nas/bin/nas_diskmark -m -a
        print_vb("11b y $year m $mon d $day h $hr m $min s $sec \n");
    }
    elsif (exists $months{$chunks[1]} && exists $days{$chunks[0]})
    {
        $year = $chunks[4];
        $mon  = $months{$chunks[1]};
        $day  = $chunks[2];
        my @chunks1 = split(/:/,$chunks[3]);
        $hr   = $chunks1[0];
        $min  = $chunks1[1];
        $sec  = $chunks1[2];
#       Thu Nov 19 16:09:31 2009 ha-policy.pl: found spb dirty wrt ISCSI_B. Going to reboot spb        
#       Mon May 24 16:34:32 UTC 2010: Upstart: c4-boot: pre-start completed
        if( $year eq "UTC" )
        {
            $year = $chunks[5];
            print_vb("22a y $year m $mon d $day h $hr m $min s $sec \n");
        }
        else
        {
            print_vb("22b y $year m $mon d $day h $hr m $min s $sec \n");
        }
    }
    elsif (exists $months{$chunks[1]})
    {
        $year = $chunks[2];
        $mon  = $months{$chunks[1]};
#        $day  = $days{$chunks[0]};
        $day  = $chunks[0];
        my @chunks1 = split(/:/,$chunks[3]);
        $hr   = $chunks1[0];
        $min  = $chunks1[1];
        $sec  = $chunks1[2];
#       16 May 2010 23:52:28  - [UIServices] INFO  - {0:3334:350731250}
        print_vb("33 y $year m $mon d $day h $hr m $min s $sec \n");
    }
    elsif (exists $months{$chunks[0]})
    {
        $year = 2012;
        if ( $gyear )
        {
            $year = $gyear;
        }
        $mon  = $months{$chunks[0]};
        $day  = $chunks[1];
        my @chunks1 = split(/:/,$chunks[2]);
        $hr   = $chunks1[0];
        $min  = $chunks1[1];
        $sec  = $chunks1[2];
#       May 24 10:30:44 spa crmd: [21102]: WARN: update_failcount: Updating failcount
        print_vb("44 y $year m $mon d $day h $hr m $min s $sec \n");
    }
    elsif ( $chunks[0] eq "Type:" )
    {
        my @chunks1 = split(/([:,-])/,$chunks[2]);
        $mon  = $chunks1[0];
        $day  = $chunks1[2];
        $year = $chunks1[4];
        @chunks1 = split(/([:,-])/,$chunks[3]);
        $hr   = $chunks1[0];
        $min  = $chunks1[2];
        $sec  = $chunks1[4];
        print_vb("60 y $year m $mon d $day h $hr m $min s $sec \n");
    } 
    elsif ( $chunks[0] eq "DATE:" )
    {
        for( my $i=0; $i < scalar(@chunks); $i++ )
        {
            my @chunks1 = split(/\//,$chunks[$i]);
            if ( scalar(@chunks1) == 3 )
            {
                $year = $chunks1[0]; 
                $mon  = $chunks1[1];
                $day  = $chunks1[2];
            }
        }
        $gyear = $year;
        $gmon  = $mon;
        $gday  = $day;
        return;
    }
    elsif ( length($chunks[0]) == 11 )
    {
        my @chunks1 = split(/:/,$chunks[0]);
#       1267186563: DPSVC: 6:  DpInit::taskManagerInit() Done
        print_vb("77 $chunks1[0]\n");
        return ($chunks1[0] + $GMT_to_local_offset);
    }
    elsif ( ($chunks[1] =~ /"spa"/) || ($chunks[1] =~ /"spb"/) )
    {
        my @chunks1 = split(/([",\-,T,:,.])/,$chunks[8]);
        if (exists $months{$chunks1[2]})
        {
            $mon  = $months{$chunks1[2]};
            $day  = $chunks[9];
            $year = $chunks[11]; 
            chomp($chunks[10]);
            @chunks1 = split(/([",\-,T,:,.])/,$chunks[10]);
            $hr   = $chunks1[0];
            $min  = $chunks1[2];
            $sec  = $chunks1[4];
#           "8T05:19:24.297Z" "spa" "C4_logEventApplication" "10183" "unix/spa/root" "INFO" "" :: "Mar 18 05:19:23 2011 CS_PLATFORM:NASDB"
            print_vb("99 hr $hr min $min sec $sec mon $mon day $day year $year\n");
        }
        else
        {
            chomp($chunks[0]);
            @chunks1 = split(/([",\-,T,:,.])/,$chunks[0]);
            $year = $chunks1[2]; 
            if (( $year eq "2010" ) || ($year eq "2011") || ($year eq "2012") || ($year eq "2013"))
            {
                $mon  = $chunks1[4];
                $day  = $chunks1[6];
                $hr   = $chunks1[8];
                $min  = $chunks1[10];
                $sec  = $chunks1[12];
#               "2010-08-18T17:00:05.097Z" "spb" "C4_ccsx" "15335" "" "ERROR" 
                print_vb("88 hr $hr min $min sec $sec mon $mon day $day year $year\n");
            }
            else
            {
                $year = $gyear;
                $mon  = $gmon;
                $day  = $gday;
                $hr   = $chunks1[2];
                $min  = $chunks1[4];
                $sec  = $chunks1[6];
#               1T09:40:07.518Z" "spa" "Neo_CEM" "24500" "Local/admin" "ERROR" "14:160002" :: "System Error:
                print_vb("98 hr $hr min $min sec $sec mon $mon day $day year $year\n");
            }
        }
    }
    else
    {
        $hr = 0;
        $day = 0;
        for( my $i=0; $i < scalar(@chunks); $i++ )
        {
            my @chunks1 = split(/:/,$chunks[$i]);
            for( my $a=0; $a < scalar(@chunks1); $a++ )
            {
                print_vb("    chunks1 $a : $chunks1[$a]\n");
            }
            if ( scalar(@chunks1) == 3 )
            {
                $hr   = $chunks1[0];
                $min  = $chunks1[1];
                $sec  = $chunks1[2];
                $sec  =~ s/(\]|\[|)//g;
                if ($sec =~ '.')
                {
                    @chunks1 = split(/\./,$sec);
                    $sec  = $chunks1[0];
                }
                print_vb("  Got $hr : $min : $sec\n");
            }
            @chunks1 = split(/\//,$chunks[$i]);
            if (( scalar(@chunks1) == 3 ) && ( $chunks1[2] > 2000 ))
            {
                $mon  = $chunks1[0];
                $day  = $chunks1[1];
                $year = $chunks1[2]; 
                @chunks1 = split(/(\d+)/,$chunks1[0]);
                if( scalar(@chunks1) == 2 )
                {
                    $mon  = $chunks1[1];
                } 
                else
                {
                    my $cnt = scalar(@chunks1);
                }
                print_vb("  Got $mon / $day / $year\n");
            }
        }

        if( $hr && $day )
        {
#           slot_3: [05/17/2010 15:03:41] Timed out after 360 seconds
            print_vb("55 y $year m $mon d $day h $hr m $min s $sec \n");
        }
        elsif ( $hr && !$day )
        {
#            We could process the log again for dates on other lines. Punt for now.
            $year = $gyear;
            $mon  = $gmon;
            $day  = $gday;
#           16:31:45.870098          7         5515D940      std:TDD:   Ownership Loss
            print_vb("66 y $year m $mon d $day h $hr m $min s $sec \n");
        }
        elsif ( $line =~ "shutdown.sh" )
        {
            return $gepoch;
        }
        else
        {
            print_vb("$line\n");
            print_vb("No format match\n");
#            exit 1 if ( $VERBOSE );
            return -1;
        }
    }
    print_vb("hr $hr min $min sec $sec mon $mon day $day year $year\n");
    my $epoch;
    eval {
        $epoch = timelocal($sec, $min, $hr, $day, $mon-1, $year-1900); #converts to Epoch
    };
    if ($@) {
        if ( $line =~ "<bam" )
        {
            $epoch = $gepoch;
        }
        else
        {
            print_sp("Unable to get epoch time for \n$line");
            exit 1 if ( $VERBOSE );
            return -1;
        }
    }

    print_vb("epoch: $epoch\n");
    $gyear = $year;
    $gmon  = $mon;
    $gday  = $day;
    $gepoch = $epoch;
    return $epoch;
}

sub print_vb
{
    my $line = shift;
    if( $VERBOSE )
    {
        if ( $line !~ "DATE:" )
        {
            print $line;
        }
    }
}

sub print_sp
{
    my $line = shift;
    if( !$SUPRESS )
    {
        print $line;
    }
}

sub print_image_rev
{
    my $filename = "general_information.txt";
    my @files=`find $ARTF_PATH -name $filename`;
    foreach my $file (@files)
    {
        my @grep_lines=`grep 'Image Version' $file`;
        foreach my $line (@grep_lines)
        {
            if ( $file =~ "spa" )
            {
                print("SPA: $line");
            }
            elsif ( $file =~ "spb" )
            {
                print("SPB: $line");
            }
            else
            {
                print("$line");
            }
        }
    }
}

sub calc_cdxic_offsets
{
    my $filename = "c4_cdxic2_native.log";
    my @files=`find $ARTF_PATH -name $filename`;
    if (  scalar(@files) > 0 )
    {
        $filename = @files[0];
        my @date_lines=`grep 'initial clock value' $filename`;
        if ( scalar(@date_lines) > 0 )
        {
            my $line = join('',@date_lines);
            my @chunks = split(' ',$line);
            my @chunks1 = split(/([:])/,$line);
            my $line = @chunks[6]." ".@chunks[7]." ".@chunks[8]." ".@chunks[9]." ".@chunks[10]." cdx line";
            my $epoch1 = @chunks1[0];
#            print_vb("LINE: $line");
            my $epoch2 = gettime($line);
            $GMT_to_local_offset = $epoch2 - $epoch1;
#            print_vb("TIME: $epoch1 $epoch2 $GMT_to_local_offset\n");
        } 
        else
        {
            print_vb("file $filename does not contain term\n");
        }
    }
    else
    {
        print("Can't find $filename\n");
    }
}

sub calc_ktrace_offsets
{
    my @files=`find $ARTF_PATH -name c4_ccsx_ktrace.log`;
    my $fnum = scalar(@files);
    if ( $fnum == 2 )
    {
        my @spa_ring_buf;
        my @spb_ring_buf;

        foreach my $filename (@files)
        {
            if ( $filename =~ "spa_" )
            {
                @spa_ring_buf=`grep RING_BUF $filename`; 
                my $spa_cmi = join('',@spa_ring_buf);
#                print_vb("SPA:\n$spa_cmi");
            }
            else
            {
                @spb_ring_buf=`grep RING_BUF $filename`;
                my $spb_cmi = join('',@spb_ring_buf);
#                print_vb("SPB:\n$spb_cmi");
            }
        }

# Incomplete, need to look for multiple matches of same addr
        foreach my $line (@spa_ring_buf)
        {
            # key looks like: addr=0xa8545b38
            my @chunks  = split(' ',$line);
            my @chunks1 = split(/([:])/,$line);
            my $spahr   = $chunks1[0];
            my $spamin  = $chunks1[2];
            my @chunks2 = split(/[.]/,$chunks1[4]);
            my $spasec  = $chunks2[0];
            my $key = $chunks[7];
            print_vb("spa: $line");
            @chunks = split(/[=]/,$key);
            if( $chunks[0] eq "addr" )
            {
                $key = "address=" . $chunks[1];
            }
            else
            {
                $key = "addr=" . $chunks[1];
            }
            foreach my $spb_line (@spb_ring_buf)
            {
                if ( $spb_line =~ $key )
                {
                    @chunks1    = split(/([:])/,$spb_line);
                    my $spbhr   = $chunks1[0];
                    my $spbmin  = $chunks1[2];
                    @chunks2    = split(/[.]/,$chunks1[4]);
                    my $spbsec  = $chunks2[0];
                    my $spa_offset = 0;
                    $spa_offset = ((($spahr - $spbhr) * (60*60)) + (($spamin - $spbmin) * 60) + ($spasec - $spbsec));
                    print_vb("spb: $spb_line");
                    print_vb("spa h $spahr m $spamin s $spasec $spa_offset\n");
                    print_vb("spb h $spbhr m $spbmin s $spbsec \n");
                    calc_ktrace_cem_offset(($spa_offset * -1));
                    return;
                }
            }
        }
    }
    else
    {
        print("unable to find two ktrace logs: $fnum\n");
        sleep(4);
    }
}

# Find a bind request, find a create LUN request, diff them
sub calc_ktrace_cem_offset
{
    my $spa_to_spb_diff = shift;
    my @kfiles=`find $ARTF_PATH -name c4_ccsx_ktrace.log`;
    my $fnum = scalar(@kfiles);
    foreach my $kfile (@kfiles)
    {
        my @bind_cmds=`grep LUSM_BIND_COMPLETE $kfile`;
        my $kcount = scalar(@bind_cmds);
        if ( $kcount > 0 )
        {
            my $ktrace_epoch = gettime($bind_cmds[($kcount - 1)]);
            if ($ktrace_epoch == -1)
            {
                $SPA_ktrace_offset = -1 + $fudge_factor;
                $SPB_ktrace_offset = -1 + $fudge_factor;
                return;
            }
            my @cfiles=`find $ARTF_PATH -name cemtracer.log`;
            foreach my $cfile (@cfiles)
            {
                my @create_cmds=`grep 'Making call to create LUN' $cfile`;
                my $ccount = scalar(@create_cmds);
                if ( $ccount > 0 )
                {
                    my $cem_epoch   = gettime($create_cmds[($ccount - 1)]);
                    my $offset = $cem_epoch - $ktrace_epoch;
                    if ( $kfile =~ "spa_" )
                    {
                       $SPA_ktrace_offset = $offset - 1 + $fudge_factor;
                       $SPB_ktrace_offset = ($offset - $spa_to_spb_diff) - 1 + $fudge_factor;
                    }
                    else
                    { 
                       $SPA_ktrace_offset = ($offset - $spa_to_spb_diff) - 1 + $fudge_factor;
                       $SPB_ktrace_offset = $offset - 1 + $fudge_factor;
                    }
                    print_vb("file: $kfile\n");
                    print_vb("SPA $SPA_ktrace_offset SPB $SPB_ktrace_offset\n");
                    return;
                }
            }
        }
    }
    $SPA_ktrace_offset = $spa_to_spb_diff;
    $SPB_ktrace_offset = 0;
}

sub match_ars 
{
     check_AR436407();
     check_AR437128();
     check_AR428332();
     check_AR438515();
     check_AR441201();
# Need better Dual Pent AR
     check_AR465484(); 
     check_AR466482(); 
}

sub check_AR466482
{
    # Look for upstart retarts
    my @files=`find $ARTF_PATH -name 'messages*'`;
    foreach my $filename (@files)
    {
        my $SP = file_to_sp($filename);
        my @lines=`grep 'init: Re-executing' $filename`;
        foreach my $line (@lines)
        {
            print("Detected AR466482 Init restart \n");
            print("$SP $line");
            show_date($lines[0]);
        }
    }
}

sub check_AR465484
{
    # Find all dates that linux rebooted
    my @files=`find $ARTF_PATH -name 'messages*'`;
    my %reboot_dates;
    foreach my $filename (@files)
    {
        my $SP = file_to_sp($filename);
        my @lines=`grep 'syslog-ng starting' $filename`;
        foreach my $line (@lines)
        {
            my $epoch = gettime($line);
            if ( !exists $reboot_dates{$epoch})
            {
                $line = "$epoch $SP $line";
                $reboot_dates{$epoch} = $line;
            }
        }
    }

    @files=`find $ARTF_PATH -name 'sptool_-d_-l.txt'`;
    foreach my $filename (@files)
    {
        my $SP = file_to_sp($filename);
        open(FP, "$filename") || die ("Unable to open svc_network file $filename\n");
        my @dmi_log=<FP>;
        close(FP);
        my $lastline;
        foreach my $line (@dmi_log)
        {
            if (($line =~ /CPU_IERR/) || ($line =~ /Machine Check:/))
            {
                chomp($line);
                chomp($lastline);
                my $epoch = gettime($lastline);
                
                $line = "$epoch $SP $lastline WARNING: The Pentium took a CPU_IERR\n" if ($line =~ /CPU_IERR/);
                $line = "$epoch $SP $lastline WARNING: The Pentium took a Machine Check\n" if ($line =~ /Machine Check/);
                my $key = $epoch . $SP;
                if ( !exists $reboot_dates{$key} )
                {
                    $reboot_dates{$key} = $line;
                }
            }
            $lastline = $line;
        }
    }
    my @sortorder;
    foreach my $key ( %reboot_dates)
    {
        push @sortorder, $reboot_dates{$key};
    }
    @sortorder = sort(@sortorder);
    my $lasttime  = 0;
    my $lastline;
    my $foundcpua = 0;
    my $foundspa  = 0;
    my $foundcpub = 0;
    my $foundspb  = 0;
    foreach my $line (@sortorder)
    {
        my $epoch = gettime($line);
        $lasttime = $epoch if( !$lasttime );
        if(($foundcpua || $foundcpub) && (($epoch - $lasttime) > 60))
        {
            if($foundcpua && $foundcpub)
            {
                print("Detected Dual SP CPU_IERR Pentium Reboot\n");
                show_date($lastline);
            }
            elsif($foundspa && $foundspb)
            {
                print("Detected Dual SP Reboot associated with Pentium error/Machine Check\n");
                show_date($lastline);
            } 
            else
            {
                print("Detected Single SP Reboot associated with Pentium error/Machine Check\n");
                show_date($lastline);
            }
            $foundcpua = 0;
            $foundspa  = 0;
            $foundcpub = 0;
            $foundspb  = 0;
        }
        if (($line =~ /CPU_IERR/) || ($line =~ /Machine Check/))
        {
            if($line =~ /SPA/)
            {
                $foundcpua = 1;
            }
            else
            {
                $foundcpub = 1;
            }
        }
        else
	{
            if($line =~ /SPA/)
            {
                $foundspa = 1;
            }
            else
            {
                $foundspb = 1;
            }
        }
        $lasttime = $epoch;
        $lastline = $line;
    }
}

sub check_AR424026
{
# SYNC WATCHDOG:thrds suspended for 60000 msec, dirtycnt=131019 prev=0

}

sub check_AR441201
{
    my $found = 0;
    my $example = "";
    my @files=`find $ARTF_PATH -name '*messages*'`;
    foreach my $filename (@files)
    {
        my @lines=`grep 'save_dump.pl aisexec' $filename`;
        my $SP = file_to_sp($filename);
        foreach my $line (@lines)
        {
            print("Detected AR441201 Crash of aisexec Fixed by SLES11 SP1\n");
            print("$SP $line");
            show_date($lines[0]);
            return;
        }
    }
}

sub check_AR438515
{
    my $found = 0;
    my $example = "";
    my @files=`find $ARTF_PATH -name 'c4_ccsx_ktrace*'`;
    foreach my $filename (@files)
    {
        my @lines=`grep 'is in power up state, fail the assign' $filename`;
        if (scalar(@lines) > 20)
        {
            print("Detected AR438515 Disk Stuck in Power Up state\n");
            show_date($lines[0]);
            return;
        }
        @lines=`grep 'Possibly bad backend disk connection' $filename`;
        if (scalar(@lines) > 20)
        {
            print("Detected AR438515 Disk Stuck in Power Up state\n");
            show_date($lines[0]);
            return;
        }
    }
}

sub check_AR428332
{
    my $found = 0;
    my $example = "";
    my @files=`find $ARTF_PATH -name 'c4_cdxic*'`;
    foreach my $filename (@files)
    {
        my @lines=`grep 'Not found next compounded request after SMB2_IOCTL' $filename`;
        if (scalar(@lines))
        {
            print("Detected AR428332 Cifs panic with Windows 7 \n");
            show_date($lines[0]);
        }
    }
}

sub check_AR437128
{
    my $found = 0;
    my $example = "";
    my @files=`find $ARTF_PATH -name 'c4_cdxic*'`;
    foreach my $filename (@files)
    {
        my $SP = file_to_sp($filename);
        my @lines=`grep 't get a free page' $filename`;
        $found = 1 if (scalar(@lines));
        $example = $lines[0] if (scalar(@lines));
        @lines=`grep 'addrspac: cannot find 2' $filename`;
        $found = 2 if (scalar(@lines));
        $example = $lines[0] if (scalar(@lines));
        my @Uncached_lines=`grep 'Buffer Uncached Pools' $filename`;
        if (scalar(@Uncached_lines))
        {
            my @chunks = split(' ',$Uncached_lines[0]);
            my $count = $chunks[4];
            $count =~ s/\(//;
            if ($count > 10000)
            {
                print("$SP Detected AR434566 Dart Memory exhaustion in multi-server jumbo environment\n");
                show_date($Uncached_lines[0]);
                $found = 0;
            }
        }
        @lines=`grep 'BlockMap page allocator' $filename`;
        if (scalar(@lines))
        {
            print("$SP Detected AR414526 Dart Memory exhaustion in Blockmap allocator\n");
            show_date($lines[0]);
            $found = 0;
        }
        if ($found)
        {
            my $memsz = get_mem_size();
            my $uptime = get_days($example);
            if (($memsz == 3994) && ($uptime > 30))
            {
                print("Detected AR427710 Dart xml Memory Leak\n");
                show_date($example);
                $found = 0;
            }
        }
        #437128 can be eliminated via 1500 configs
        #414526 can be eliminated via port mr1
        print("$SP Detection one of AR437128/AR414526/AR427710 Dart Memory exhaustion\n") if ($found == 1);
        print("$SP Detection one of AR437128/AR414526 Dart Memory exhaustion\n") if ($found == 2);
        show_date($example) if ($found);
        $found = 0;
    }
}

sub check_AR436407
{
    my $found = 0;
    my $example = "";
    my @files=`find $ARTF_PATH -name 'c4_cdxic*'`;
    my $fSP;
    foreach my $filename (@files)
    {
        my $SP = file_to_sp($filename);
        my @lines=`grep ThreadsServicesSupervisor $filename`;
        foreach my $line (@lines)
        {
            my @chunks = split(' ',$line);
            my $secs = $chunks[4];
            $secs =~ s/ThreadsServicesSupervisorISCSIISCSIExec//;
            $found = 1 if ($secs > 60);
            $fSP = $SP if ($secs > 60);
            $example = $line;
        }
    }
    print("$fSP Detected Iscsi threads are paused for too long (Possibly AR436407) \n") if ($found);
    show_date($example) if ($found);
}

sub show_network
{
    open(FP, "$SVC_STOR") || die ("Unable to open svc_network file $SVC_STOR\n");
    my @storage_config=<FP>;
    close(FP);

## NEO_EthernetPort:
##  Obj Key:                   1:0-3:0-4:1-13:0
##  Number:                    0
##  State:                     NEO_SYMPTOM_NO_FAULT
##  Is fault :                 false
##  Is link Up :               true
##  Is inserted:               true
##  Is state unknown:          false
##  Is aggregated:             true
##  Is master port:            true
##  Speed:                     1000
##  MTU size:                  1500
##  Parent Obj Key:            1:0-3:0-4:1
##  PAPI name:                 eth2
##  Link aggregation ObjKey:   1:0-3:0-4:1-14:0

    print "======= Ethernet config: =================\n";
    print "\tdevice \tlinkup \tMTU \taggregated\n";
    my $showit = 0;
    my $eth_nm = "";
    my $eth_st = "";
    my $eth_ag = "";
    my $eth_mt = ""; 
    my $bs_tm  = "";
    foreach my $line (@storage_config)
    {
        my @chunks = split(' ', $line);
        $eth_st = $chunks[5] if ($line =~ /Is link Up/);
        $eth_ag = $chunks[3] if ($line =~ /Is aggregated/);
        $eth_mt = $chunks[3] if ($line =~ /MTU size/);
        if ($line =~ /PAPI name/)
        {
            $eth_nm = $chunks[3];
            print "DEV: \t$eth_nm \t$eth_st \t$eth_mt \t$eth_ag \n";
        }
    }
    print "==========================================\n";
    open(FP, "$SVC_NW") || die ("Unable to open search term file $SVC_NW\n");
    my @nw_config=<FP>;
    close(FP);

    my $showit = 0;
    my $showline = 0;
    foreach my $line (@nw_config)
    {
        $showit = 0 if ( $showit && ($line =~ /Now running/));
        $showit = 1 if ( $line =~ /server_ifconfig/ );
        $showit = 1 if ( $line =~ /server_config ALL/ );
        if ( $showit )
        {
            $showline = 1 if ($line =~ /connections/); 
            $showline = 1 if ($line =~ /retransmit/); 
            $showline = 1 if ($line =~ /server/); 
            $showline = 3 if ($line =~ /if_/); 
        }
        print "$line" if ($showline);
        $showline-- if ($showline);
    }
    print "$SVC_STOR";
    print "$SVC_NW";
}

sub show_config
{
    open(FP, "$SVC_STOR") || die ("Unable to open search term file $SVC_STOR\n");
    my @storage_config=<FP>;
    close(FP);
    my $SAS_DR=`grep -c NEO_DISK_TYPE_SAS $SVC_STOR`;
    my $NL_SAS_DR=`grep -c NEO_DISK_TYPE_NL_SAS $SVC_STOR`;
    print "==============================================================\n";
    print "Disks:\n\tSAS:\t$SAS_DR\tNL SAS:\t$NL_SAS_DR\n";

    my $showit = 0;
    foreach my $line (@storage_config)
    {
        $showit = 0 if ( $showit && ($line =~ /Now running/));
        $showit = 1 if ( $line =~ /server_iscsi ALL -mask/ );
        $showit = 2 if ( $line =~ /server_iscsi ALL -target -info/ );
        $showit = 1 if ( $line =~ /server_export ALL/ );
        if( $showit == 2 )
        {
            next unless (($line =~ /server/) || ($line =~ /Target/) || ($line =~ /Portal:/));
        } 
#        $showit = 1 if ( $line =~ /server_cifs ALL/ );
        print "$line" if ($showit && (length($line) > 2));        
    }
    print "$SVC_STOR";
    print "$SVC_NW";
}

sub get_mem_size
{
    my $size = 0;
    my @files=`find $ARTF_PATH -name c4_gms_svr_ic_native.log`;
    foreach my $filename (@files)
    {
        my @lines=`grep 'Total physical memory' $filename`;
        if ( scalar(@lines))
        {
            my @chunks = split(' ',$lines[0]);
            $size = $chunks[5];
            $size =~ s/memory=//;
#            print("SZ: $size\n");
        }
    }
    return $size;
}

sub show_date
{
    my $line = shift; 
    my $epoch = gettime($line);
    my $local = localtime($epoch);
    print("$local epoch: $epoch\n");
}

sub get_days
{
    my $line = shift;
    my $days = 0;
    # Find all dart run stops,
    # find one with 60 seconds of passed line 
    # return that number of days
    my $epoch = gettime($line);
    my @files=`find $ARTF_PATH -name start_c4.log*`;
    foreach my $filename (@files)
    {
        my @lines=`grep 'EXIT -- module: CDX' $filename`;
        foreach my $exit_line (@lines)
        {
            if ($exit_line =~ m/RUN/)
            {
                my $exit_epoch = gettime($exit_line);
                my $diff = abs($exit_epoch - $epoch);
                if (abs( $exit_epoch - $epoch) < 120 )
                {
                    my @chunks = split(' ',$exit_line);
                    $days = $chunks[14]/(60*60*24);
#                    print("Found: $chunks[14] $days\n");
                }
            }
        }
    } 
    return $days; 
}
