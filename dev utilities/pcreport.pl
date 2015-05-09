#!/usr/bin/perl
use warnings;
use strict;

use Getopt::Long;
use IO::File;

my %VERBOSE = (
    bundle_glob => 0,
    bundle_file => 0,
    rpmlist_glob => 0,
    rpmlist_file => 0,
    processed => 0,
    names => 0,
    info => 0,
    rpm_versions => 0,
    directories => 0,
);

my %WARNING = (
    parameters_stat => 0,
    sanity_log_parse => 0,
    sanity_information => 0,
    build_dir => 0,
    no_project => 1,
    no_host => 1,
    unknown_host => 0,
    no_environment => 0,
    unparsed_env => 1,
    neo_install_log => 1,
    pathrelease_mismatch => 1,
    no_bundle => 0,
    bad_bundle => 0,
    no_bom => 0,
    bom_contents => 1,
    no_rpmlist => 0,
    no_platform => 1,
    no_flavor => 1,
    bad_rpmlist => 1,
    image_mismatch => 1,
    duplicate_rpm => 0,
    rpm_missing => 0,
    rpm_parse => 1,
    flavor_mismatch => 0,
    platform_mismatch => 1,
    image_platform => 0,
    parse_image => 0,
    no_log => 0,
    open_log => 0,
);

my %rpm_info = (
    cs => { platform => 0, repo => 'cs' }, 
    'C4Core-base' => { platform => 1, repo => 'c4core' },
    'C4Core-full' => { platform => 1, repo => 'c4core' },
    cem => { platform => 0, repo => 'cp' },
    cemcli => { platform => 0, repo => 'cp' },
    csx => { platform => 1, repo => 'csx' },
);

my @columns = qw/id project status dir started completed runtime pathtools tools c4core csx image cp cs platform flavor host/;
my @optional_columns = qw/dir started completed runtime pathtools tools csx/;

my $neo_build_dir = '/c4shares/re/Results/c4build/c4build1';
my $strip_dir_prefix = '/c4site/SOBO/Results/';
my $user_pattern = '*/{Neo-sanity-,Suite-,PreCommit-}*';
my $all_pattern = $strip_dir_prefix . '*/' . $user_pattern;
my $bad_flavor = '?????';
my $bad_repo_revision = '?????';

my @included_columns = ();
my $all = 0;
my $since;
my $warnings;
my $verbose;
my $limit_warnings = 0;
my $ascending = 0;
my @users = ();

if (defined $ENV{PCREPORT_ARGS}) {
    my @new_args = split /\s+/, $ENV{PCREPORT_ARGS};
    @ARGV = (@new_args, @ARGV);
}
GetOptions('include=s' => \@included_columns,
           'since=s' => \$since,
           'warnings!' => \$warnings,
           'verbose!' => \$verbose,
           'ascending' => \$ascending,
           'user=s' => \@users,
           'all!' => \$all);

if (defined $warnings) {
    $WARNING{$_} = $warnings for keys %WARNING;
}
if (defined $verbose) {
    $VERBOSE{$_} = $verbose for keys %VERBOSE;
}

sub resolve_host(@)
{
    my ($spa, $spb) = @_;
    if ($spa =~ /^[0-9.]+$/) {
        my @bytes = split /\./, $spa;
        if (@bytes == 4) {
            my $packed = pack("C4", @bytes);
            my @host = gethostbyaddr($packed, 2);
            $spa = $host[0] if @host;
        }
    }
    $spa =~ s/\.sspg\.lab\.emc\.com$//;
    $spa =~ s/\.rtp\.dg\.com$/ (RTP)/;
    return $1 if $spa =~ /(.*)-[sc]pa[. ]?/;
    return $1 if $spa =~ /^(sim64-[^. ]*)/;
    warn "Unknown host: @_\n" if $WARNING{unknown_host};
    return $spa;
}

sub filter_line($$@)
{
    my $pattern = shift;
    my $single_match = shift;
    my @lines = grep /$pattern/, @_;
    return wantarray ? () : undef if not @lines or ($single_match and @lines != 1);
    my @result = $lines[0] =~ /$pattern/;
    return wantarray ? @result : $1;
}

sub process_rpms($$%)
{
    my $info_ref = shift;
    my %info = %$info_ref;
    my $bad_ref = shift;
    my %rpms = @_;

    # Extra information from RPM versions
    for my $rpm (keys %rpm_info) {
        print "$rpm: $rpms{$rpm}\n" if $VERBOSE{rpm_versions};
        unless (exists $rpms{$rpm}) {
            warn "RPM $rpm is missing\n" if $WARNING{rpm_missing};
            $bad_ref->{$rpm_info{$rpm}->{repo}}++;
            next;
        }
        unless ($rpms{$rpm} =~ /^$rpm-((?:[^.]|(?:\d\.(?=\d)))+)\.([^.]+)\.(?:([A-Z]+[0-9]*)\.)?(DEBUG|RETAIL)(?:\.\d+)?-\d+$/) {
            warn "RPM version parsing error for $rpm: $rpms{$rpm}\n" if $WARNING{rpm_parse};
            next;
        }
        my $revision = "$1-r$2";
        if (exists $info{$rpm_info{$rpm}->{repo}}) {
            if ($info{$rpm_info{$rpm}->{repo}} ne $revision) {
                $info{$rpm_info{$rpm}->{repo}} = $bad_repo_revision;
            }
        } else {
            $info{$rpm_info{$rpm}->{repo}} = $revision;
        }
        if (exists $info{flavor}) {
            if ($info{flavor} ne $4 and $info{flavor} ne $bad_flavor) {
                warn "Flavor mismatch for $info{id} first found in RPM $rpm ($4 instead of $info{flavor})\n" if $WARNING{flavor_mismatch};
                $info{flavor} = $bad_flavor;
            }
        } else {
            $info{flavor} = $4;
        }
        if ($rpm_info{$rpm}->{platform}) {
            warn "Platform mismatch for $info{id} between BOM ($info{platform}) and $rpm RPM ($3)\n"
                unless $info{platform} eq $3 or not $WARNING{platform_mismatch};
        }
    }

    %$info_ref = %info;
    $info_ref->{$_} .= '(*)' for keys %$bad_ref;
}

sub read_bundle_file($$) {
    my $bundle_file = shift;
    my $info_ref = shift;

    print "BUNDLE_FILE: $bundle_file\n" if $VERBOSE{bundle_file};
    if (system("unzip -l '$bundle_file' >/dev/null 2>&1") != 0) {
        warn "Bad bundle file $bundle_file\n" if $WARNING{bad_bundle};
        return;
    }
    my $bom_content = qx{unzip -p '$bundle_file' BOM.txt 2>/dev/null};
    if (not length $bom_content) {
        warn "Failed to get BOM contents for $bundle_file ($info_ref->{id})\n" if $WARNING{no_bom};
        return;
    }
    my $BOM = eval $bom_content;
    if (not defined $BOM) {
        warn "Error evaluating BOM contents: $@\n" if $WARNING{bom_contents};
        return;
    }

    # Platform in BOM appears to alway be correct, although flavor may not be
    if (exists $info_ref->{platform} and $info_ref->{platform} ne $BOM->{Target}) {
        warn "Platform in image ($info_ref->{platform}) does not match the BOM ($BOM->{Target})\n" if $WARNING{image_mismatch};
    }
    $info_ref->{platform} = $BOM->{Target};

    my %rpms = ();
    my %bad_repo = ();
    foreach my $rpm (@{$BOM->{BOM}}) {
        if (exists $rpms{$rpm->{name}}) {
            warn "Duplicate entry for $rpm->{name} in BOM for bundle $bundle_file\n" if $WARNING{duplicate_rpm};
            $bad_repo{$rpm_info{$rpm->{name}}->{repo}}++ if exists $rpm_info{$rpm->{name}};
        }
        $rpms{$rpm->{name}} = $rpm->{version};
    }
    process_rpms $info_ref, \%bad_repo, %rpms;

    return 1;
}

sub read_rpmlist($$) {
    my $rpmlist_file = shift;
    my $info_ref = shift;
    my %rpms = ();
    my %bad_repo = ();

    print "RPMLIST_FILE = $rpmlist_file\n" if $VERBOSE{rpmlist_file};

    unless (exists $info_ref->{platform}) {
            warn "Platform is required when reading RPM list $rpmlist_file" if $WARNING{no_platform};
            return;
    }
    unless (exists $info_ref->{flavor}) {
            warn "Flavor is required when reading RPM list $rpmlist_file" if $WARNING{no_flavor};
            return;
    }

    my $rpmlist_fh = new IO::File $rpmlist_file, 'r';
    my %tgt_hash = ();
    my $line = $rpmlist_fh->getline();
    if (not $line =~ /^:\s+TITLE$/) {
        warn "Unable to parse RPM list $rpmlist_file: no match on TITLE\n" if $WARNING{bad_rpmlist};
        return;
    }
    while (defined chomp($line = $rpmlist_fh->getline())) {
        if ($line =~ /^:/) {
            warn "Unable to parse RPM list $rpmlist_file: no match on PKG_GRP\n" if $WARNING{bad_rpmlist};
            return;
        }
        if ($line =~ /^\s+PKG_GRP;/) {
            $tgt_hash{$_}++ for split /,/, $';
            last;
        }
    }
    while (not $rpmlist_fh->eof()) {
        my %rpminfo = ();
        while (defined chomp($line = $rpmlist_fh->getline())) {
            last if $line =~ /^:/ or $rpmlist_fh->eof();
            if ($line =~ /^\s*(\S+)(?:\s+(.*?))?\s*$/) {
                $rpminfo{$1} = $2;
            } else {
                warn "Unable to parse RPM list $rpmlist_file: Bad line \"$line\"\n" if $WARNING{bad_rpmlist};
            }
        }
        next if not exists $rpminfo{RPM_NAME};
        my $skip_rpm = 0;
        foreach my $key (keys %rpminfo) {
            if (exists $rpminfo{$key} and exists $tgt_hash{$key} and not
                ($key eq $info_ref->{platform} or $key eq $info_ref->{flavor})) {
                $skip_rpm = 1;
                last;
            }
        }
        next if $skip_rpm;
        my $rpm_full = $rpminfo{RPM_NAME};
        if (not $rpminfo{RPM_NAME} =~ /^([^.]*)-[^-.]*?\./i) {
            warn "RPM parse error: $rpm_full" if $WARNING{rpm_parse};
            next;
        }
        my $rpm_name = $1;
        if (exists $rpms{$rpm_name}) {
            warn "Duplicate entry for $rpm_name in rpmlist $rpmlist_file\n" if $WARNING{duplicate_rpm};
            $bad_repo{$rpm_info{$rpm_name}->{repo}}++ if exists $rpm_info{$rpm_name};
        }
        $rpms{$rpm_name} = $rpminfo{RPM_NAME};
    }
    $rpmlist_fh->close();

    process_rpms $info_ref, \%bad_repo, %rpms;

    return 1;
}

sub process_dir($) {
    my $dir = shift;
    my %info = (dir => $dir);
    $info{dir} =~ s{$strip_dir_prefix}{}o;

    # Scarf environment.sh file
    my $env_fn = $dir . '/environment.sh';
    my $env_fh = new IO::File $env_fn, 'r';
    if (not defined $env_fh) {
        warn "Unable to open file $env_fn: $!\n" if $WARNING{no_environment};
        return;
    }
    my %env = ();
    $info{started} = '?????';
    while (defined(my $env = $env_fh->getline())) {
        $info{started} = $1 if $env =~ /^#\s*create.*at:\s*(.*)$/;
        next unless $env =~ /^export /;
        chomp($env);
        if ($env !~ m{^export [^=']+='}) {
            warn "Unparsable content in environment file ($env_fn): $env\n" if $WARNING{unparsed_env};
            next;
        }
        while ($env !~ m{'$}) {
            my $next_line = $env_fh->getline();
            die "Unexpected EOF in $env_fn" unless defined $next_line;
            chomp($next_line);
            $env .= "\n" . $next_line;
        }
        $env =~ m{^export ([^=']+)='(.*)'$}s or die "Logic error in environment parsing";
        $env{$1} = $2;
    }

    # Read log file
    my @logs = glob $dir . '/*.log';
    if (@logs != 1) {
        warn "Unable to identify log file for $dir\n" if $WARNING{no_log};
        return;
    }
    my $log_fn = $logs[0];
    my $log_fh = new IO::File $log_fn, 'r';
    if (not defined $log_fh) {
        warn "Unable to open file $log_fn: $!\n" if $WARNING{open_log};
        return;
    }
    my @log_lines = $log_fh->getlines();
    $log_fh->close();
    my $is_sanity = ($log_fn =~ m{-sanity\.log$});

    # Get information from environment.sh file
    if (not exists $env{C4_PROJECT}) {
        warn "C4_PROJECT is not defined in $env_fn" if $WARNING{no_project};
        $info{project} = '????';
        #return;
    } else {
        $info{project} = $env{C4_PROJECT};
    }
    return if $info{project} eq 'papi'; # No support for papi test yet
    my $host_value = $env{C4_HOST};
    if (not defined $host_value or not length $host_value) {
        warn "No C4_HOST defined in $env_fn\n" if $WARNING{no_host};
        return;
    }
    $info{host} = resolve_host(map(/@(.*)/, split(/,/, $host_value)));
    $info{id} = $env{C4_RESULTID};
    $info{revision} = $env{C4_REVISION};
    my $neo_pathrelease = $env{C4_NEO_PATHRELEASE};
    $info{branch} = $env{C4_BRANCH};
    $info{pathtools} = $env{C4_PATHTOOLS};
    $info{tools} = exists $env{C4_REVISIONTOOLS} ? $env{C4_REVISIONTOOLS} : '????';

    # Figure out the image from the Image Install test that uploads the image
    $info{image} = '?????';
    my $image_platform;
    my $image_flavor;
    my $log_glob = '/{Image{,OS}-Install,install-os}-*/*.log';
    my @test_logs = sort glob $dir . $log_glob;
    if (not @test_logs) {
        $log_glob = '/test-*/*.log';
        @test_logs = sort glob $dir . $log_glob;
    }
    foreach my $log_fn (@test_logs) {
        my $log_fh = new IO::File $log_fn, 'r';
        if (defined $log_fh) {
            my ($branch, $rev, $modified);
            my @image_info = &filter_line(qr{Uploading.* to (?:/var)?/tmp/(?:upgrade/images/)?OS-([^-]+)-\d+\.\d+\.(\d+)(?:-(\d+))?-([A-Z0-9]+)-([A-Z]+).tgz.bin}, 0, $log_fh->getlines());
            if (@image_info) {
                $info{image} = "$image_info[0]-r$image_info[1]";
                $info{image} .= 'M' if defined $image_info[2];
                $info{platform} = $image_platform = $image_info[3];
                $info{flavor} = $image_flavor = $image_info[4];
                last;
            }
        }
    }

    # Scarf BOM.txt file
    my $bundle_root_dir = $dir . "/build-{image,neo}-*-r*";
    my $bundle_dir = $bundle_root_dir . "/Dist";

    if ($is_sanity) {
        # The most authoritative source would be the actual Neo Install log
        my $log_glob = '/Neo-Install-*/Neo-Install.log';
        my @logs = sort glob $dir . $log_glob;
        warn "Too many Neo-Install log files for $info{id}\n" if @logs > 1 and $WARNING{neo_install_log};
        foreach my $log_fn (@logs) {
            my $log_fh = new IO::File $log_fn, 'r';
            if (defined $log_fh) {
                my $uploaded_bundle = &filter_line(qr{Uploading\s+(\S+)\s+to}, 0, $log_fh->getlines());
                if (defined $uploaded_bundle) {
                    warn "Uploaded bundle ($uploaded_bundle) doesn't match PathRelease ($neo_pathrelease)\n" if defined $neo_pathrelease and $neo_pathrelease ne $uploaded_bundle;
                    $neo_pathrelease = $uploaded_bundle;
                }
            }
        }
    }

    if ($is_sanity and not defined $neo_pathrelease) {
        unless (defined $image_flavor and defined $image_platform) {
            warn "Unable to determine information from Image Install log file for sanity run $info{id}" if $WARNING{sanity_information};
            return;
        }
        unless (defined $info{branch} and $info{revision}) {
            warn "Unable to determine branch and revision information to identify bundle for sanity run $info{id}" if $WARNING{sanity_information};
            return;
        }
        my $build_dir = $neo_build_dir . "/Suite-neo-$info{branch}-r${info{revision}}{,-*}";
        my @build_matches = glob $build_dir;
        if (not @build_matches) {
            warn "No build directory matches $build_dir" if $WARNING{build_dir};
            return;
        }
        @build_matches = glob "$build_dir/build-{image,neo}-*";
        $build_dir = $neo_build_dir unless @build_matches;
        $bundle_dir = $build_dir . "/build-{image,neo}-$info{branch}-r${info{revision}}-$image_flavor-${image_platform}{,-*}/Dist";
    }

    # See if there's a bundle
    my $bundle_glob;
    if (defined $neo_pathrelease) {
        $bundle_glob = $neo_pathrelease;
    } elsif (not defined $info{branch} or $info{branch} eq 'trunk' or $info{branch} eq 'UseImaging') {
        $bundle_glob = $bundle_dir . "/c4bundle-neo.{UseImaging,trunk}.*";
    } else {
        $bundle_glob = $bundle_dir . "/c4bundle-neo.{$info{branch},UseImaging,trunk}.*";
    }
    print "BUNDLE_GLOB: $bundle_glob\n" if $VERBOSE{bundle_glob};
    my @bundles = glob $bundle_glob;
    if (@bundles == 1) {
        &read_bundle_file($bundles[0], \%info) or return;
    } elsif (@bundles != 0) {
        warn "Too many bundles for $dir ($info{id})\n" if $WARNING{no_bundle};
        return;
    } else {
        # See if there's an rpmlist for the upgrade image
        my $rpmlist_glob = $bundle_root_dir . "/rpmlist-Build-*";
        print "RPMLIST_GLOB: $rpmlist_glob\n" if $VERBOSE{rpmlist_glob};
        my @rpmlists = grep !/-BEFORE-UPDATE$/, (glob $rpmlist_glob);
        if (@rpmlists != 1) {
            warn "Failed to find rpmlist for $dir ($info{id})\n" if $WARNING{no_rpmlist};
            return;
        }
        my $rpmlist_file = $rpmlists[0];
        read_rpmlist $rpmlists[0], \%info or return;
    }

    # Grok the status from the top-level log file
    $info{status} = '????';
    $info{completed} = '?????????';
    $info{runtime} = '????????';
    my @completed = grep /Completed Test/, @log_lines;
    if (@completed == 1) {
        if ($completed[0] =~ m/Completed Test $info{id} at ([^,]+), elapsed runtime (.*)/) {
            $info{completed} = $1;
            $info{runtime} = $2;
        } 
    }
    my @status = grep /^\s*Status\s*:/, @log_lines;
    if (@status) {
        my $notrun = grep /NOTRUN/, @status;
        my $pass = grep /PASS/, @status;
        my $fail = grep /FAIL/, @status;

        if ($pass == (@status - $notrun) and $fail == 0) {
            $info{status} = 'PASS';
        } elsif ($fail != 0) {
            $info{status} = 'FAIL';
        }
    } else {
        $info{status} = '<N/A>';
    }

    if ($VERBOSE{info}) {
        print "  $_ = $info{$_}\n" for keys %info;
    }
    print "Processed PreCommit # $info{id} ...\n" if $VERBOSE{processed};

    return %info;
}

# Build a list of directories (use hash to avoid duplicates)
my %directories = map { ($_, 1) } @ARGV;
%directories = (%directories, map { ($_, 2) } glob($all_pattern)) if $all or (defined $since and not %directories and not @users);
%directories = (%directories, map { ($_, 3) } glob("$strip_dir_prefix$_/$user_pattern")) for @users;
if (defined $since) {
    my $timestamp = `date -d '$since' +\%s`;
    die "Unable to value time value \"$since\"" unless length $timestamp;
    foreach my $dir (keys %directories) {
        my @stat = stat($dir . '/parameters.c4p');
        if (@stat) {
            delete $directories{$dir} unless $stat[9] >= $timestamp;
        } else {
            print STDERR "Unable to stat parameters.c4p in $dir: $!\n" if $WARNING{parameters_stat};
        }
    }
}
if ($VERBOSE{directories}) {
    print "DIRECTORY: $_\n" for sort keys %directories;
}

# Read results from each directory
my @results = ();
foreach my $arg (sort keys %directories) {
    $arg =~ s{/parameters\.c4p$}{};
    my %info = process_dir($arg);
    push @results, \%info if exists $info{id};
}

# Remove included columns from the optional list
foreach my $col (@included_columns) {
    @optional_columns = grep { $_ ne $col } @optional_columns;
}

# Remove remaining optional columns from the column list
foreach my $col (@optional_columns) {
    @columns = grep { $_ ne $col } @columns;
}

# Size columns based on maximum content
my %colmax = ();
foreach my $col (@columns) {
    $colmax{$col} = length $col;
    foreach my $result (@results) {
        my $len = defined $result->{$col} ? length $result->{$col} : 0;
        $colmax{$col} = $len if $len > $colmax{$col};
    }
}

# Print report
# Note: headers go to STDERR so that they bypass grep
foreach my $col (@columns) {
    printf STDERR "\%-$colmax{$col}s ", uc($col);
}
printf STDERR "\n";
my @sorted = sort { $b->{id} <=> $a->{id} } @results;
@sorted = reverse @sorted if $ascending;
foreach my $result (@sorted) {
    foreach my $col (@columns) {
        printf "\%-$colmax{$col}s ", defined $result->{$col} ? $result->{$col} : '';
    }
    printf "\n";
}
