#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  contribs.pl
#
#        USAGE:  ./contribs.pl
#
#  DESCRIPTION: This is a terribly ugly script that does the job
#
#      OPTIONS:  ---
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  YOUR NAME (),
#      COMPANY:
#      VERSION:  1.0
#      CREATED:  09/02/2012 15:34:24
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;

use Modern::Perl '2012';
use Carp;
use Data::Dumper;
use HTTP::Tiny;
use IO::Socket::SSL; # Needed for https URLs
use Text::CSV_XS;
use IO::All;

# Go grab the public spreadsheet of contributors
my $url
    = 'https://docs.google.com/spreadsheet/pub?key=0AgZzmiG9MvT4dHZRRloyb1ZhT3dmN2RhMHFVZUhZQ3c&single=true&gid=0&output=csv';

my $response = HTTP::Tiny->new->get( $url );
my $data;
my $file;

if ( $response->{'success'} ) {
    $data = $response->{'content'};
}


# If we got it, let's save it as a .csv
# Text::CSV seems to prefer files over strings
if ( $data ) {
    my $io = io 'contributors-from-gd.csv';
    $data > $io;
    $file = $io->filename;
}

# Let's turn that CSV into a nice array of hashes
my @contribs;
if ( $file ) {
    my $csv = Text::CSV_XS->new( { binary => 1, eol => $/ } );
    open my $io, "<", $file or croak "$file: $!";
    my $fields = $csv->getline( $io );
    while ( my $row = $csv->getline( $io ) ) {
        my $i       = 0;
        my %contrib = ();
        for my $col ( @$fields ) {
            $contrib{$col} = @$row[$i];
            $i++;
        }
        push @contribs, \%contrib;
    }
    $io->close;
}

# Let's find just the folks who are in the book, and sort that list by last name
my @book_contribs = map { $_->{'Contributed Book'} ? $_ : () } @contribs;
my @book_sorted
    = sort { $a->{'Last name'} cmp $b->{'Last name'} } @book_contribs;

# Let's turn that array into HTML
my $contrib_str;
if ( @book_sorted ) {
    my $last = pop @book_sorted;
    for my $contrib ( @book_sorted ) {
        my $name = $contrib->{'First name'} . ' ' . $contrib->{'Last name'};
        my $bio  = $contrib->{'Bio'};
        if ( $bio ) {
            $contrib_str .= <<HTML;
<a href="index.shtml#contributors" onclick="return hs.htmlExpand(this, { headingText: '$name' })">$name</a><div class="highslide-maincontent">$bio</div>, 
HTML
        }
        else {
            $contrib_str .= "$name, ";
        }
        my $l_name = $last->{'First name'} . ' ' . $last->{'Last name'};
        my $l_bio  = $last->{'Bio'};
    }
        $contrib_str .= <<LAST;
and <a href="index.shtml#contributors" onclick="return hs.htmlExpand(this, { headingText: '$l_name' })">$l_name</a><div class="highslide-maincontent">$l_bio</div>.
LAST
}

# Let's output the string into an HTML file for inclusion on the page
my $html = io 'contributors.html';
$contrib_str > $html;

# Let's close the filehandle
$html->close;
