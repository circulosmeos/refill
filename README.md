refill
======

**Complete (refill) a file with parts of another file.**   
Bytes 0x0 are considered refillable if one of the two files has a non 0x0 value.   
In case one file is bigger than the other, the extra bytes will be considered good data and appended to output.   
FILE_1 values take precedence over FILE_2 bytes in case different but non-zero values are found at the same byte position.   

The script can run both in linux and in Windows. In Windows, a previous Perl installation is needed, like [strawberry Perl](http://strawberryperl.com/) or [ActiveState Perl](https://www.activestate.com/products/perl/)).

Usage
=====

    Complete (refill) a file with parts of another - v1.0
    Bytes 0x0 are considered refillable if one of the two files has a non 0x0 value.
    In case one file is bigger than the other, the extra bytes will be considered
    good data and appended to output.

    Use:

      ./refill.pl [-0123n#hsV] FILE_1 FILE_2 [ OUTPUT_FILE ]

    FILE_1 values take precedence over FILE_2 bytes in case different but
    non-zero values are found at the same byte position.

    Please note that in linux simple quotation marks are preferred: ''
    whilst in Windows double quotation marks are needed: ""

      -0: Use stdout for output

      -1: overwrite FILE_1 with parts of FILE_2 (no OUTPUT_FILE needed)

      -2: overwrite FILE_2 with parts of FILE_1 (no OUTPUT_FILE needed)

      -3: Default option: use OUTPUT_FILE as output

      -n#: number of bytes per read block (by default 1048576 (1 MiB))

      -h: show this help

      -s: silent mode

      -v: show version and explanation of chars used in ASCII output

      -V: verbose mode. Up to `-VVVVV`.


Examples of use
===============

Suppose you have FILE_1 which has entire blocks of data erased or absent (that is, all binary zeroes) and FILE_2 which corresponds to the same whole file, but with holes of data in different parts:   
Can the original and complete file be recovered from both of them?   
Let's try:   

    $ perl refill.pl FILE_1 FILE_2 complete_file

    1(@0+629, 1 B).....................................
    ........1(@69632+1023, 222 B)+(@70656+1024, 1024 B)
    End Of File FILE_1
    ²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²
    ²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²
    ²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²²
    End Of File FILE_2
    OK

Now `complete_file` will contain a file made up from filled chunks from FILE_1 and FILE_2: if the holes didn't overlap, this is the complete original file. If the holes overlap, but not completely, this file will contain more data, but not all.

Also, one can use one of the files as source and destination of the recovery: **Please, be aware that this overwrites the original file data!** Use at your own risk. For example to do the same thing than in the previous example, but making FILE_1 directly the recovered file:

    $ perl refill.pl -1 FILE_1 FILE_2

Legend
======

Legend: each read block is represented with one char indicating:

    .       block is equal in both files
    *       block is refilled with bytes from FILE_1 and FILE_2
    +       " " " " " from FILE_1 and FILE_2 and is appended data from one of them
    1       " " " " " from FILE_1
    2       " " " " " from FILE_2
    ¹       " " " " " from FILE_1 and is also appended data from FILE_1
    ²       " " " " " from FILE_2 and is also appended data from FILE_2

License
=======

Distributed [under GPL 3](http://www.gnu.org/licenses/gpl-3.0.html)

Disclaimer
==========

**This software is provided "as is", without warranty of any kind, express or implied. In no event will the authors be held liable for any damages arising from the use of this software.**

Author
======

by [Roberto S. Galende](loopidle@gmail.com)   