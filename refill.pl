#!/usr/bin/env perl
#
#
#
use strict;

use Digest::MD5 qw(md5_hex);

my $BUFFER_LENGTH = 2**10;

my ( $FILE_1, $FILE_2, $FILE_3 );
my $parameters = '';
my $MODE = 3; # expected third filename for output

my $VERBOSE == 0;

#-------------------------------------------------------------------------------


$parameters = shift @ARGV or goto SHOW_MAN_PAGE;

if ( $parameters =~ /^\-\w+$/ ) {

    if ( $parameters =~ /^\-[\-0123Phv\?]+$/ ) {

        if ( $parameters =~ /[h\?]/ ) {
            goto SHOW_MAN_PAGE;
        }

        if ($parameters ne '') {
                # -h was previously processed and implied immediate end.
                $MODE = 0 if $parameters =~ /0/; # use STDOUT as output
                $MODE = 1 if $parameters =~ /1/; # overwrite 1st file
                $MODE = 2 if $parameters =~ /2/; # overwrite 2nd file
                $VERBOSE = 1 if $parameters =~ /v/; # verbose mode
                $VERBOSE = 2 if $parameters =~ /vv/; # verbose mode
        }

        $FILE_1 = shift;

    } else {

        print STDERR "Parameters contain unrecognized options: '$parameters'\nwhilst expected: '-[0123Phv]'\n";
        exit 1;

    }

} else {

    $FILE_1 = $parameters;
    $parameters = '';

}

$FILE_2 = shift or goto SHOW_MAN_PAGE;;

if ( $parameters !~ /^\-.*[012]/ ) {

    # if not otherwise indicated, a third file is needed for output
    $FILE_3 = shift;

}


#-------------------------------------------------------------------------------


if ( $MODE == 0 ) {
    open fOut, '>-:raw';
}

if ( $MODE != 1 ) {
    open f1, '<:raw', $FILE_1;
} else {
    open f1, '+<:raw', $FILE_1;
}

if ( $MODE != 2 ) {
    open f2, '<:raw', $FILE_2;
} else {
    open f2, '+<:raw', $FILE_2;
}

if ( $MODE == 3 ) {
    open fOut, '>:raw', $FILE_3;
}

my $offset = 0;
my ($bytes_read1, $bytes_read2, $bytes1, $bytes2, $i, $refilling_type);

while ( 1 ) {

    my $good_string = '';
    my $difference = '.';
    my $number_of_differences = 0;

    $bytes_read1 = read ( f1, $bytes1, $BUFFER_LENGTH );

    $bytes_read2 = read ( f2, $bytes2, $BUFFER_LENGTH );

    if ( $bytes_read1 == 0 ) {
        if ( $bytes_read2 == 0 ) {
            # EOF for both files has been reached,
            # so exit while loop as there's nothing more to do:
            last;
        } else {
            # that is, eof(f1) and no f1 content read in this run
            # but there's still f2 content to add: we will trick
            # the for loop to think that $bytes1 and $bytes2 are equal:
            $bytes_read1 = $bytes_read2;
            $bytes1 = $bytes2;
            $refilling_type = 2; # to choose the appropriate informative STDERR char 
        }
    }

    print STDERR "[bytes_read1= $bytes_read1, bytes_read2= $bytes_read2]" if $VERBOSE == 1;
    print STDERR "[offset= $offset]" if $VERBOSE == 2;

    if (  md5_hex($bytes1) ne md5_hex($bytes2) ) {

        for ( $i = 0; $i < $bytes_read1 or $i < $bytes_read2; $i++ ) {

            # last bytes: FILE_1 and FILE_2 have different sizes
            if ( $bytes_read1 != $bytes_read2 and
                ( $i == $bytes_read1 or $i == $bytes_read2 )
                ) {

                my $tail_string = substr( ( ($bytes_read1 < $bytes_read2)?$bytes2:$bytes1 ), $i );
                $number_of_differences += length( $tail_string );
                $good_string .= $tail_string;

                ($difference eq '.' || $difference eq '1')?($difference = '¹'):($difference = '+');
                ($difference eq '.' || $difference eq '2')?($difference = '²'):($difference = '+') if $i == $bytes_read1;

                $i = ($bytes_read1 < $bytes_read2)?$bytes_read2:$bytes_read1;

                last;

            }

            my $char1 = ord( substr($bytes1, $i, 1) );
            my $char2 = ord( substr($bytes2, $i, 1) );

            if ( $char1 != $char2 ) {

                $number_of_differences++;

                if ( $char1 == 0 ) {
                    $good_string .= chr( $char2 );
                    if ( $char2 != 0 ) {
                        ($difference eq '.' || $difference eq '2')?($difference = '2'):($difference = '*');
                    }
                } else {
                    # in case both files differ in != 0x0 values, FILE_1 takes precedence
                    $good_string .= chr( $char1 );
                    ($difference eq '.' || $difference eq '1')?($difference = '1'):($difference = '*');
                }

            } else {

                $good_string .= chr( $char1 );

            }

        }

        if ( $MODE == 1 ) {
            # how many bytes do we must go backwards in f1?
            # always $bytes_read1 (which can be 0)
            seek( f1, $bytes_read1, 1 );
            print f1 $good_string;
        } elsif ( $MODE == 2 ) {
            # how many bytes do we must go backwards in f2?
            # always $bytes_read2 (which can be 0)
            seek( f2, $bytes_read2, 1 );
            print f2 $good_string;
        } else  {
            print fOut $good_string;
        }

    } else {

        $i = $bytes_read1; # $bytes_read1 and $bytes_read2 are equal
        
        if ( $refilling_type == 2 ) {
            $difference = '²';
        }

        print fOut $bytes1;

    }

    print STDERR "[i= $i]" if $VERBOSE == 2;

    print STDERR $difference;
    if ( $difference ne '.' and $bytes_read1 != 0 and $bytes_read2 != 0
         and $refilling_type != 2
         or ( $difference eq '+' ) ) {
        print STDERR "(\@$offset+$i, $number_of_differences B)";
    }
    $|=1;

    if ( $bytes_read1 != $BUFFER_LENGTH or $bytes_read2 != $BUFFER_LENGTH
         and ( $bytes_read1 != 0 and $bytes_read2 != 0 )
         or  ( $bytes_read1 == 0 and $bytes_read2 == 0 ) ) {
        print STDERR "\nEOF\n";
    }

    $offset += $i;

}

close f1;
close f2;
close fOut;

print STDERR "OK\n";

exit(0);

#-------------------------------------------------------------------------------


SHOW_MAN_PAGE:


print STDERR <<MAN_PAGE;

Complete (refill) a file with parts of another.
Bytes 0x0 are considered refillable if one of the two files has a non 0x0 value.
In case one file is bigger than the other, the extra bytes will be considered
good data and appended to output.

Use:

  ./refill.pl [-0123Ph] FILE_1 FILE_2 [ OUTPUT_FILE ]

FILE_1 values take precedence over FILE_2 bytes in case different but
non-zero values are found at the same byte position.

Please note that in linux simple quotation marks are preferred: '' 
whilst in Windows double quotation marks are needed: ""

  -0: Use stdout for output

  -1: overwrite FILE_1 with parts of FILE_2 (no OUTPUT_FILE needed)

  -2: overwrite FILE_1 with parts of FILE_1 (no OUTPUT_FILE needed)

  -3: Default option: use OUTPUT_FILE as output

  -h: show this help

  -v: verbose mode
MAN_PAGE