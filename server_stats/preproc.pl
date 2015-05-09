#!/usr/bin/perl

# modules
use strict;
use warnings;
use POSIX;
use Scalar::Util ("looks_like_number") ;
use Data::Dumper ;


use constant PROGRAM => "preproc.pl  1.20" ;


#############################################################################
# Copyright (C) 2013
# EMC Corporation
# All Rights Reserved
#
# 	preproc.pl - version 1.0
#
# This perl script will read a CSV file, determine which columns do not have
# values greater than zero, and create a new CSV file that does not have the
# columns with a sum of zero. If the first character of the file is not a quote,
# each field will be quoted when it is written. If the seconds are missing from
# the timestamps, they are added.
#
# see the Help subroutine for more info
#
# history:
#	07/12/2013 Glenn Mead - Created initial release
#   08/12/2013 Glenn Mead - Add support for -c
#                           Modify timestamp handling to handle missing seconds
#
#############################################################################


# global declarations
use constant MIN_VALUE => 0 ;	# defines the minimum value that will be counted

my @value_count ;				# array of counters, one for each column, used to count how many values are greater than MIN_VALUE
my $infile ;					# CSV input pathname
my $outfile ;					# CSV output pathname
my $has_quotes ;				# if the file does not start with a quote, quote each field when it is written
my $inFH ;						# input file handle
my $outFH ;						# output file handle
my $row ;						# current row being processed
my $zero_col_count ;			# number of columns with a zero sum
my $row_count ;					# number of rows in this CSV file
my $col_count ;					# max number of columns on any row
my $last_col ;					# last column to process for the current loop
my $seconds_per_update = 0 ;	# frequncy in seconds of the updates
my $first_seconds = 0 ;			# seconds value to be used for the first timestamp
my $last_timestamp = "" ;		# timestamp of the last row read
my $seconds ;					# seconds value to add to the timestamp
my $max_col = 0 ; 				# defines how many of the available columns should be written (not counting the timestamp)


#############################################################################
# main
#############################################################################

# check the commandline
if ($#ARGV < 0) {
	DisplayHelp() ;
} else {
	for (my $ctr = 0 ; $ctr <= $#ARGV ; $ctr++) {
		if ($ARGV[$ctr] eq "-i") {
			$ctr++;
			$infile = $ARGV[$ctr] ;
		} elsif ($ARGV[$ctr] eq "-o") {
			$ctr++ ;
			$outfile = $ARGV[$ctr] ;
		} elsif ($ARGV[$ctr] eq "-c") {
			$ctr++ ;
			$max_col = $ARGV[$ctr] ;
		} elsif ($ARGV[$ctr] eq "-h") {
			DisplayHelp() ;
		} elsif ($ARGV[$ctr] eq "-?") {
			DisplayHelp() ;
		} else {
			print "\nERROR - Invalid command line.\n" ;
			DisplayHelp() ;
		}
	}
}

# build the default output filename if needed
if (!defined $outfile) {
	$outfile = $infile ;
	$outfile =~ s/csv$/preproc.csv/i ;
}

DisplayMsg("The ouptut file is: $outfile\n") ;
DisplayMsg("Restricting processing to the first $max_col columns.\n") if ($max_col > 0) ;
DisplayMsg("Opening the files ...\n") ;

# open the input and output file
open($inFH, "<$infile")  || die "Could not open $infile for reading:\n$!" ;
open($outFH, ">$outfile") || die "Could not open $outfile for writing:\n$!" ;

# if the first character of the file is a quote, assume the fields are
# already quoted and don't need quotes when writing to the output file.
$has_quotes = CheckForQuotes($inFH) ;
if ($has_quotes == 1) {
	DisplayMsg("The input file has quotes.\n") ;
} else {
	DisplayMsg("The input file does not have quotes, they will be added to the output file.\n") ;
}

# check the timestamps
CheckTimestamps($inFH, \$seconds_per_update, \$seconds) ;

# force acceptance of column 0 as the timestamp column
$value_count[0] = 1 ;

# Read the file and determine which columns do not have sums > MIN_VALUE.
# Instead of summing the values, which could possibly result in an overflow,
# count the times the value is greater than MIN_VALUE.
DisplayMsg("Determining which columns have a zero sum ...\n") ;
$row = 0 ;
$col_count = 0 ;
while (<$inFH>) {
	# remove quotes so numbers are numbers and not strings
	if ($has_quotes == 1) {
		$_ =~ s/\x22//g ;
	}
	my @in = split /,/ ;

	# column count can change throughout the file
	if ($#in > $col_count) {
		$col_count = $#in ;
	}

	# happy lights
	$row++ ;
	if ($row % 500 == 0) {
		DisplayMsg("Reading row $row\n") ;
	}

	# start at column 1, we already handled the timestamp column (col 0)
	# look at the columns we care about
	# this needs to done for each row as $#in can change within the file
	if ($max_col > 0) {
		$last_col = $max_col > $#in ? $#in : $max_col ;
	} else {
		$last_col = $#in ;
	}
	foreach my $col (1 .. $last_col) {
		# make sure it is a number
		if (looks_like_number($in[$col])) {
			if ($in[$col] > MIN_VALUE) {
		   		$value_count[$col] += 1 ; # this column has a value
		   	}
		}
	}
}

# remember how many rows (records) there are
$row_count = $row ;

# now that we know how many columns are in the file, adjust $max_col
if ($max_col < 1) {
	$max_col = $col_count ;
} else {
	$max_col = $col_count > $max_col ? $max_col : $col_count ;
}

# Set all un-initialized sums to 0, as they don't have any values.
# This will make it easier to step through the array later as we
# won't have to check for undefined values each time.
$zero_col_count = 0 ;
foreach my $col (1 .. $max_col) {
	# set undefined sums to MIN_VALUE since they have no value
	if (!defined $value_count[$col]) {
		$value_count[$col] = 0 ; # makes sure all value_count[] have been initialized
	}

	# count zero sum columns since we are already going through the array
	if ($value_count[$col] == 0) {
		$zero_col_count++ ;
	}
}

# display file stats
DisplayMsg("There are $row_count rows in this file.\n") ;
DisplayMsg("There are $col_count columns in this file.\n") ;
DisplayMsg("There are $zero_col_count columns with a zero sum in the first $max_col columns.\n") ;
DisplayMsg("Creating $outfile.\n") ;

# seek back to the beginning of the input file
seek($inFH, 0, 0) ;

# read through the input file and write out each row with
# only the columns that have a total greater than 0
$row = 0 ;
while(<$inFH>) {
	my @in = split /,/ ;
	my $out = '' ;
	my $col = 0 ;

	# set $last_timestamp to $in[0] so the seconds are set correctly on the first row
	$last_timestamp = $in[0] if $row == 1 ;

	# happy lights
	$row++ ;
	if ($row % 500 == 0) {
		DisplayMsg("Writing row $row of $row_count ...\n") ;
	}

	# handle the timestamps (except in the header). If the seconds are missing, add them
	if ($in[0] !~ m/time/i) {
		if ($seconds_per_update) { # we need to set the seconds
			if ($in[0] ne $last_timestamp) {
				$last_timestamp = $in[0] ;
				$seconds = 0 ;
				$in[0] .= ":00" ;
			} else {
				if ($seconds > 60) {
					DisplayMsg("Timestamps are invalid around row $row.\n") ;
					exit 1 ;
				}
				$last_timestamp = $in[0] ;
				$in[0] .= sprintf(":%02d",$seconds) ;
				$seconds += $seconds_per_update ;
			}
		}
	}

	# add quotes if needed to the timestamp
	if ($has_quotes == 1) {
		# no quotes needed, alread quoted
		$out .= $in[$col] . "," ;
	} else {
		# this file did not have quoted values, so quote them
		$out .= "\"" . $in[$col] . "\"," ;
	}

	# step through the columns and write out the ones that have a sum greater than MIN_VALUE
	my $good_col_count = 0 ;
	$last_col = $max_col < $#in ? $max_col : $#in ;
	foreach $col (1 .. $last_col) {
		if ($value_count[$col] > 0) {
			# this column has one or more values greater than MIN_VALUE, so write it out
			$good_col_count++ ;
			if ($has_quotes == 1) {
				# no quotes needed, alread quoted
				$out .= $in[$col] . "," ;
			} else {
				# this file did not have quoted values, so quote them
				$out .= "\"" . $in[$col] . "\"," ;
			}
		}
		if ($good_col_count == $max_col) {
			last ;
		}
	}

	# remove the last comma
	$out = substr($out,0,-1) ;

	# write the row plus the terminator
	# the last column will contain the terminator. If the last column has no
	# values greater than MIN_VALUE it will not be written so we need to add a terminator
	if (substr($out,-1) ne "\x0a") {
		$out .= "\x0a" ;
	}
	print $outFH $out || die "Could not write to $outfile:\n $!" ;
}

# close the files
close($inFH) ;
close($outFH) ;

DisplayMsg("$outfile has been created.\n") ;

#############################################################################
# end of main
#############################################################################
exit 0 ;



#############################################################################
#
# DisplayHelp
# - Display the help message
#
# arguments
#	none
#
# returns
#	none
#############################################################################
sub DisplayHelp {
	print "\n" . PROGRAM . "\n" ;
	print "\n    description:\n" ;
	print "        * removes columns with a zero sum from CSV files.\n" ;
	print "        * quotes fields if the first character in the input file is not a quote.\n" ;
	print "        * overwrites the output file if it already exists.\n" ;
	print "\n    options:\n" ;
	print "        -h display this help message\n" ;
	print "        -? display this help message\n" ;
	print "        -c columncount (optional - Only includes the first x columns instead of the whole row)\n" ;
	print "           All columns except the timestamp column are counted, even if they have a zero sum.\n" ;
	print "        -i inputfilename (required)\n" ;
	print "        -o outputfilename (optional)\n" ;
	print "           outputfilename defaults to inputfilename.preproc.csv\n" ;
	exit 1 ;
}



#############################################################################
#
# CheckForQuotes
#
# - Seeks to the beginning of the file
# - Reads the first row from the file
# - Checks if the first character is a quote
# - Seeks to the beginning of the file
#
# arguments:
#    filehandle
#
# returns:
#    1 - the first character of the file is a quote
#    0 - the first character of the file is not a quote
#
#############################################################################
sub CheckForQuotes {
	(my $fh) = @_ ;

	# seek to the beginning of the file
	seek $fh, 0, 0 ;

	# read the first row from the file
	my $in = <$fh> ;

	# seek to the beginning of the file (for the next consumer)
	seek $fh, 0, 0 ;

	# see if the first character is a quote
	if ($in =~ m/^\x22/) {
		return 1 ; # quote found
	} else {
		return 0 ; # no quote found
	}
}



#############################################################################
#
# DisplayMsg
#
# Displays a time stamped message to the screen
#
# arguments:
#    string containing the message
#
# returns:
#    none
#
#############################################################################
sub DisplayMsg {
	my ($msg) = @_ ;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time) ;
    my $timestamp = sprintf ( "%02d:%02d:%02d",
                               $hour,$min,$sec) ;
    print "$timestamp - $msg" ;
}



#############################################################################
#
# CheckTimestamps
#
# Determines the update frequency in seconds and the first update seconds value
#
# arguments:
#    string containing the message
#
# returns:
#    none
#
# sets the value of:
#    $seconds_per_update	update interval. Used to increment $seconds
#    $seconds				timestamp seconds value for the first timestamp
#
# assumptions:
#	 there are more than 3 rows
#
#############################################################################
sub CheckTimestamps {
	my ($fh, $seconds_per_update, $seconds) = @_ ;
	my $first_minute_update_count = 0 ;

	# seek to the beginning of the file, just to be safe
	seek $fh, 0, 0 ;

	# get the first timestamp
	my $in = <$fh> ; # skip the header
	$in = <$fh> ;

	# don't choke on an empty file
	if (!defined $in) {
		DisplayMsg("Input file is empty or corrupt\n") ;
		exit 2 ;
	}

	my @fields = split(',', $in) ;
	my $first_timestamp = $fields[0] ;
	$first_minute_update_count = 1 ;

	# if the timestamp contains hh:mm:ss, we are all done
	if ($first_timestamp =~ m/[0-9][0-9]:[0-9][0-9]:[0-9][0-9]$/) {
		$$seconds_per_update = 0 ;
		$$seconds = 0 ;
		return ;
	}

	# get the next timestamp
	$in = <$fh> ;
	@fields = split(',', $in) ;
	my $timestamp = $fields[0] ;

	# make sure we have another row
	if ($#fields < 0) {
		DisplayMsg("Input file does not have enough rows\n") ;
		exit 2 ;
	}


	# read until we get a different timestamp to insure we are at the beginning of a minute
	while($timestamp eq $first_timestamp) {
		$first_minute_update_count++ ;
		$in = <$fh> ;
		my @fields = split(',', $in) ;
		if ($#fields < 0) {
			DisplayMsg("Input file does not have enough rows\n") ;
			exit 2 ;
		}
		$timestamp = $fields[0] ;
	}
	$first_timestamp = $timestamp ;

	# get the next timestamp
	$in = <$fh> ;
	@fields = split(',', $in) ;
	if ($#fields < 0) {
		DisplayMsg("Input file does not have enough rows\n") ;
		exit 2 ;
	}
	$timestamp = $fields[0] ;

	# count how many timestamps are the same (from the same minute)
	my $count = 1 ;
	while($timestamp eq $first_timestamp) {
		$count++ ;
		$in = <$fh> ;
		@fields = split(',', $in) ;
		if ($#fields < 0) {
			DisplayMsg("Input file is empty or corrupt\n") ;
			exit 2 ;
		}
		$timestamp = $fields[0] ;
	}

	# seek to the beginning of the file (for the next consumer)
	seek $fh, 0, 0 ;

	# return update frequency
	if ($count == 1) { # a count of one means that each time stamp is already different
		$$seconds_per_update = 0 ;
		$$seconds = 0 ;
	} else {
		$$seconds_per_update = 60 / $count ;
		$$seconds = ($$seconds_per_update * $first_minute_update_count) ;
		DisplayMsg("Timestamps are being adjusted to include seconds. Updates were calculated to be every $$seconds_per_update seconds.\n") ;
	}
}


# end of program
exit 0 ;
__END__