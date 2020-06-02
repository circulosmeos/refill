#!/usr/bin/env perl
#
#
#
use strict;

use Digest::MD5 qw(md5_hex);

my $BUFFER_LENGTH = 2**20;

my ( $f1, $f2, $FILE_1, $FILE_2, $FILE_3 );
my $parameters = '';
my $MODE = 3; # expected third filename for output

#-------------------------------------------------------------------------------


$parameters = shift @ARGV or goto SHOW_MAN_PAGE;

if ( $parameters =~ /^\-\w+$/ ) {

    if ( $parameters =~ /^\-[\-0123Ph\?]+$/ ) {

        if ( $parameters =~ /[h\?]/ ) {
            goto SHOW_MAN_PAGE;
        }

        if ($parameters ne '') {
                # -h was previously processed and implied immediate end.
                $MODE = 0 if $parameters =~ /0/; # use STDOUT as output
                $MODE = 1 if $parameters =~ /1/; # overwrite 1st file
                $MODE = 2 if $parameters =~ /2/; # overwrite 2nd file
        }

        $FILE_1 = shift;

    } else {

        print STDERR "Parameters contain unrecognized options: '$parameters'\nwhilst expected: '-[0123Ph]'\n";
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
    open $f1, '<:raw', $FILE_1;
} else {
    open $f1, '+<:raw', $FILE_1;
}

if ( $MODE != 2 ) {
    open $f2, '<:raw', $FILE_2;
} else {
    open $f2, '+<:raw', $FILE_2;
}

if ( $MODE == 3 ) {
    open fOut, '>:raw', $FILE_3;
}

my $offset = 0;
my ($bytes_read1, $bytes_read2);

while ( $bytes_read1 = read ( ( eof($f1)?$f2:$f1 ), my $bytes1, $BUFFER_LENGTH ) ) {

    my $good_string = '';
    my $difference = '.';
    my $number_of_differences = 0;

    $bytes_read2 = read $f2, my $bytes2, $BUFFER_LENGTH;

    if (  md5_hex($bytes1) ne md5_hex($bytes2) ) {

        for ( my $i = 0; $i < $bytes_read1 or $i < $bytes_read2; $i++ ) {

            # last bytes: FILE_1 and FILE_2 have different sizes
            if ( $bytes_read1 != $bytes_read2 and
                ( $i == $bytes_read1 or $i == $bytes_read2 )
                ) {

                $good_string .= substr( ( ($bytes_read1 < $bytes_read2)?$bytes2:$bytes1 ), $i );

                ($difference eq '.' || $difference eq '1')?($difference = '1'):($difference = '+');
                ($difference eq '.' || $difference eq '2')?($difference = '2'):($difference = '+') if $i == $bytes_read1;

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

        print fOut $good_string;

    } else {

        print fOut $bytes1;

    }

    print STDERR $difference;
    print STDERR "(\@$offset, $number_of_differences B)" if ( $difference ne '.' );
    $|=1;

    print STDERR "\nEOF\n" unless $bytes_read1 == $BUFFER_LENGTH and $bytes_read2 == $BUFFER_LENGTH;

    $offset += $BUFFER_LENGTH;

}

close $f1;
close $f2;
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
MAN_PAGE