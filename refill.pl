#!/usr/bin/env perl
#
# Complete (refill) a file with parts of another.
# Bytes 0x0 are considered refillable if one of the two files has a non 0x0 value.
# In case one file is bigger than the other, the extra bytes will be considered
# good data and appended to output.
#
# by Roberto S. Galende, June 2020
#
use strict;

use Digest::MD5 qw(md5_hex);

my $VERSION = '1.0';
my $REFILL_VERSION = 'Complete (refill) a file with parts of another - v'. $VERSION;

my $CHAR_EQUAL                      = '.';
my $CHAR_FIRST_N_SECOND             = '*';
my $CHAR_FIRST_N_SECOND_N_APPEND    = '+';
my $CHAR_FIRT                       = '1';
my $CHAR_SECOND                     = '2';
my $CHAR_FIRST_N_APPEND             = '¹';
my $CHAR_SECOND_N_APPEND            = '²';


my $BUFFER_LENGTH = 2**10;

my ( $FILE_1, $FILE_2, $FILE_3 );
my $parameters = '';
my $MODE = 3; # expected third filename for output

my $VERBOSE == 0;

my ( $number_of_bytes1, $number_of_bytes2, $bytes1, $bytes2, $i,
     $eof1_informed, $eof2_informed, $last_position_of_difference );
my $refilling_type = 0;
my $offset = 0;

#-------------------------------------------------------------------------------


$parameters = shift @ARGV or goto SHOW_MAN_PAGE;

if ( $parameters =~ /^\-\w+$/ ) {

    if ( $parameters =~ /^\-[\-0123PhvV\?]+$/ ) {

        if ( $parameters =~ /[h\?]/ ) {
            goto SHOW_MAN_PAGE;
        }

        if ( $parameters =~ /[v]/ ) {
            print STDERR "\n$REFILL_VERSION\n";
            exit (0);
        }

        if ($parameters ne '') {
                # -h was previously processed and implied immediate end.
                $MODE = 0 if $parameters =~ /0/; # use STDOUT as output
                $MODE = 1 if $parameters =~ /1/; # overwrite 1st file
                $MODE = 2 if $parameters =~ /2/; # overwrite 2nd file
                $VERBOSE = length($1) if $parameters =~ /(V+)/; # verbose mode
        }

        $FILE_1 = shift;

    } else {

        print STDERR "Parameters contain unrecognized options: '$parameters'\nwhilst expected: '-[0123PhV]'\n";
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

my ( $output, $good_string, $difference, $number_of_differences );

while ( 1 ) {

    $output;
    $good_string = '';
    $difference = '.';
    $number_of_differences = 0;

    $number_of_bytes1 = read ( f1, $bytes1, $BUFFER_LENGTH );

    $number_of_bytes2 = read ( f2, $bytes2, $BUFFER_LENGTH );

    if ( $number_of_bytes1 == 0 ) {
        if ( $number_of_bytes2 == 0 ) {
            # EOF for both files has been reached,
            # so exit while loop as there's nothing more to do:
            last;
        } else {
            # That is, eof(f1) and no f1 content read in this run
            # but there's still f2 content to add.

            # To choose the appropriate informative STDERR char,
            # and also to refill FILE_1 correctly, without backwards seeks:
            $refilling_type = 2;
        }
    }

    print STDERR "[#bytes1= $number_of_bytes1, #bytes2= $number_of_bytes2]" if $VERBOSE >= 1;
    print STDERR "[offset= $offset]" if $VERBOSE >= 2;
    print STDERR '[' . ( ( md5_hex($bytes1) eq md5_hex($bytes2) )?'eq':'ne' ) . ", $refilling_type\]" if $VERBOSE >= 3;
    print STDERR '[' . md5_hex($bytes1) .' '. md5_hex($bytes2) . "]" if $VERBOSE == 4;
    print STDERR '[' . md5_hex($bytes1) .' '. md5_hex($bytes2) . "]" if $VERBOSE >= 5;

    if ( $refilling_type == 0 &&
         md5_hex($bytes1) ne md5_hex($bytes2) ) {

        for ( $i = 0; $i < $number_of_bytes1 or $i < $number_of_bytes2; $i++ ) {

            # last bytes: FILE_1 and FILE_2 have different sizes
            if ( $number_of_bytes1 != $number_of_bytes2 and
                ( $i == $number_of_bytes1 or $i == $number_of_bytes2 )
                ) {

                my $tail_string = substr( ( ($number_of_bytes1 < $number_of_bytes2)?$bytes2:$bytes1 ), $i );
                $number_of_differences += length( $tail_string );
                $good_string .= $tail_string;

                ($difference eq '.' || $difference eq '1')?($difference = '¹'):($difference = '+');
                ($difference eq '.' || $difference eq '2')?($difference = '²'):($difference = '+') if $i == $number_of_bytes1;

                $last_position_of_difference = ($number_of_bytes1 < $number_of_bytes2)?$number_of_bytes2:$number_of_bytes1;

                last;

            }

            my $char1 = ord( substr($bytes1, $i, 1) );
            my $char2 = ord( substr($bytes2, $i, 1) );

            if ( $char1 != $char2 ) {

                $number_of_differences++;
                $last_position_of_difference = $i;

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

        $output = \$good_string;

    } else {
        # strings are equal, or $refilling_type == 2

        $i = $number_of_bytes2; # $number_of_bytes1 and $number_of_bytes2 are equal
        
        if ( $refilling_type == 2 ) {
            $difference = '²';
        }

        $output = \$bytes2;

    }

    # write output
    if ( $MODE == 1 ) {
        # how many bytes do we must go backwards in f1?
        # always $number_of_bytes1 (which can be 0)
        seek( f1, -$number_of_bytes1, 1 ) unless $refilling_type == 2;
        print f1 $$output;
    } elsif ( $MODE == 2 ) {
        # how many bytes do we must go backwards in f2?
        # always $number_of_bytes2 (which can be 0)
        seek( f2, -$number_of_bytes2, 1 ) unless $refilling_type == 2;;
        print f2 $$output;
    } else  {
        print fOut $$output;
    }


    print STDERR "[i= $i]" if $VERBOSE == 2;

    print STDERR $difference;
    if ( $difference ne '.' and $eof1_informed == 0 and $eof2_informed == 0 ) {
        print STDERR "(\@$offset+$last_position_of_difference, $number_of_differences B)";
    }
    $|=1;

    #if ( $number_of_bytes1 != $BUFFER_LENGTH or $number_of_bytes2 != $BUFFER_LENGTH
    #     and ( $number_of_bytes1 != 0 and $number_of_bytes2 != 0 )
    #     or  ( $number_of_bytes1 == 0 and $number_of_bytes2 == 0 )
    #     or $refilling_type == 2 ) {
        if ( ( eof(f1) or $refilling_type != 0 ) and $eof1_informed == 0) {
            print STDERR "\nEnd Of File FILE_1";
            $eof1_informed = 1;
        }
        if ( eof(f2) and $eof2_informed == 0 ) {
            print STDERR "\nEnd Of File FILE_2";
            $eof2_informed = 1;
        }
    #}

    $offset += $i;

}

close f1;
close f2;
close fOut;

print STDERR "\nOK\n";

exit(0);

#-------------------------------------------------------------------------------


SHOW_MAN_PAGE:


print STDERR <<MAN_PAGE;

$REFILL_VERSION
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

  -V: verbose mode
MAN_PAGE

exit (0);