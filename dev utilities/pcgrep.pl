#!/usr/bin/perl

###########################################
#                                         #
# pcgrep -- a paragraph-oriented grep tool #
#                                         #
# (See the embedded man page below)       #
#                                         #
###########################################

$VERSION = '$Revision$';

$VERSION_STRING=<<"EOT";
   $VERSION
EOT

# require('getopts.pl');
use Getopt::Long qw(:config no_ignore_case);

my $opt_d = '';
my $opt_f = '';
my $opt_H = '';
my $opt_h = '';
my $opt_i = '';
my $opt_L = '';
my $opt_s = ""; # separator
my $opt_S = '';
my $opt_v = '';
my $opt_V = '';
my $opt_x = ""; # command to execute

### process options

#if (! &Getopts('dfHhiLs:SvVx:'))

if ( ! &GetOptions( 'd' => \$opt_d,
                    'f' => \$opt_f,
                    'H' => \$opt_H,
                    'h' => \$opt_h,
                    'i' => \$opt_i,
                    'L' => \$opt_L,
                    's=s' => \$opt_s,
                    'S' => \$opt_S,
                    'v' => \$opt_v,
                    'V' => \$opt_V,
                    'x=s' => \$opt_x ) )
   {
    &Error("command error\n");
    exit 1;
    }

#    -h      Print short help (synopsis).
if ($opt_h or $opt_H)
    {
    &Synopsis;
    exit 0 unless ($opt_H);
    &RestOfHelp;
    exit 0;
    }

if ($opt_V)
    {
    print "$VERSION_STRING";
    exit 0;
    }

if ($#ARGV < 0)
    {
    &Error("missing search string\n");
    exit 1;
    }

$debug = 0;
if ($opt_d)
    {
    $debug = 1;
    }

$lc = 0;		# default is NOT to convert to lower case, i.e.
			# do case-insensitive search
if ($opt_i)
    {
    $lc = 1;
    }

$sep = "\n\n";          # default record separator to search paragraphs
$\ = "\n";              # set output record separator
if ($opt_s)
    {
    #$sep = eval ($opt_s);	# use user's alternative separator
    $sep = $opt_s;
    $\ = "";              # set output record separator
    }
$sep_len = length( $sep );
&Debug("separator is \"$sep\" (length = $sep_len)");


$pos = 1;		# use positive logic for match. -v reverses sense.
if ($opt_v)
    {
    $pos = 0;
    }

$omit_sep=1;		# omit separator by default; -S to keep it
if ($opt_S)
    {
    $omit_sep=0;
    }

# $pat = '';		# default search pattern is empty
$search_pat = shift;
$search_pat =~ s#/#\\/#g;
if ( $lc == 1 )
    { # convert to lower case
    $pat = "\L$search_pat\E";
    }
else
    {
    $pat = $search_pat;
    }
&Debug("search pattern is \"$search_pat\"");

### Do file glob of remaining entries in @ARGV
@new_argv = ();
while ($next = shift @ARGV)
    {
    @unglob_next = glob( $next );   # unglob one entry 
    push( @new_argv, @unglob_next );  # accumulate lists
    }
@ARGV = @new_argv;  # replace @ARGV since it's treated specially
if (defined $opt_L) 
    {
    print join( "\n", @ARGV), "\n";
    }

### Process lines from @ARGV list of files.

$/ = "$sep";            # set input record separator
#$/ = "";            # set input record separator
$, = ' ';               # set output field separator
#$* = 1;                # Enable ^ and $ within a multi-line string (no longer supported)

$length = length($sep);
$count = 0;
while (<>) {
    # extract paragraph from input line; leave the trailing
    # separator in the line, if any
    #print "\n--->\n$_\n<---\n";
    $next_spot = index($_, $sep);
    if ($next_spot >= $[) {
	#if ($omit_sep)
	#    {
	    $line = substr($_, 0, length($_)-$length);
	#    }
	#else
	#    {
	#    $line = substr($_, 0, length($_));
	#    }
        }
    else {
        $line = $_;
        }

    if ( $lc == 1 )
	{ # convert to lower case
	$matchline = "\L$line\E";
	}
    else
	{
	$matchline = $line;
	}

    # print paragraph if pattern is found
    $match = 0;
    eval ("\$match = 1 if (\$matchline =~ /$pat/m) ");
    &Debug("match $match");
    if (($match == 1) == $pos) {
        &ShowFile();
        print "$sep" unless ($omit_sep);
	$count++;
	if ($opt_x)
	    {
	    $cmd = "$opt_x";
	    &Debug("CMD: $cmd");
	    open(CMD_PIPE, "| $cmd") || die "Can't exec $cmd\n";
	    print CMD_PIPE "$line";
	    close(CMD_PIPE);
	    }
	else
	    {
	    print "$line\n";
	    }
	}

    }

exit 0;

#######
# End #
#######

sub ShowFile
{
if ($opt_f)
    {
    printf "### File: $ARGV ###\n";
    }
}

sub Synopsis
{
print <<"_EOF_";
NAME
    pcgrep -- paragraph context grep tool

SYNOPSIS
    Usage: pcgrep [-i] [-v] [-f] [-L] [-s sep] [-S] [-x cmd] pattern [fpat ..]
	   pcgrep [-h|-H]
	   pcgrep [-V]
  Options:
     -i      Do case-insensitive pattern.
     -v      Print NON-matching paragraphs.
     -f      Print file name or '-' for stdin for each match.
     -L      List expanded (glob) version of fpat.
     -s sep  Define the paragraph separator.
     -S      Print paragraph separator also. (Default is to omit it)

     -x cmd  Instead of printing the paragraph, pipe each 
             paragraph to 'cmd' and output the result.

     -h      Print short help (synopsis only).
     -H      Print long help.
     -V      Print version information.

  Arguments:
    'pattern' is the search pattern
    '[fpat ..]' is the list of file patterns (use stdin if empty)

DESCRIPTION
    Print entire paragraphs containing the given pattern in some
    line.  By default, the match is case-sensitive and a
    paragraph is delimited by a blank line.

    The string pattern follows Perl's regular expressions.

REVISION
    $VERSION
_EOF_
}

sub RestOfHelp
{
print <<"_EOF_";
SEE ALSO
    grep, egrep, cgrep(1E).

EXAMPLES
    TBD.

AUTHOR
    Eric Vook

VERSION
    $VERSION
    $DATE
_EOF_
}


sub Error
{
local($message) = @_;
print "*** $message\n";
print "Use the -h or -H options for help.\n";
}



sub Debug
{
local($message) = @_;
print "### $message\n" if ($debug);
}
