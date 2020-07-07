% LDIF2JSON(1) Version 0.1 | User Commands

NAME
====

**ldif2json** — converts LDIF format to JSON

SYNOPSIS
========

| ldif-command | **ldif2json** \[**options**\]
| **ldif2json** \[**options**\] LDIF-file \[ LDIF-file ... \]

DESCRIPTION
===========

Reads LDAP Data Interchange Format (LDIF) from standard input or files passed as arguments and writes tabular
JSON to standard output. One JSON object is written per line. By default if an attribute is a valid number for
all input records, it is coerced to a number on output.

Options
-------

-h, --help

:   Prints brief usage information.

-f, --flatten

:   By default all attribute values are arrays of values, even if only one value is present. This option converts attributes to single values if all values across all records contain only a single value. Not compatible with --join

-jSEP, --join=SEP

:   instead of outputting arrays, output single strings joined by the separator SEP

-t ATTRIBUTE:TYPE, --type=ATTRIBUTE:TYPE

:   For the attribute ATTRIBUTE interpret it as the type TYPE

    Valid values for TYPE are: "auto" (the default - if all values are valid numbers then coerce to a number,
    otherwise a string), "string", "number" (convert to a number and exit with an error if any attribute values
    are not valid numbers) and "number0" (convert to a number or 0 for values that are not valid numbers)

EXAMPLES
========

    ldapsearch [options] 'uid=*' | ldif2json --flatten | jq 'select(.cn | tostring | test("Smith$")) | .dn'

BUGS
====

See GitHub Issues: <https://github.com/joatca/ldif2json/issues>

AUTHOR
======

Fraser McCrossan

SEE ALSO
========

**jq(1)**, **ldapsearch(1)**, **slapcat(8)**
