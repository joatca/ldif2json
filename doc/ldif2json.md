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
JSON to standard output. One JSON object is written per line.

LDIF does not contain schema information and thus `ldif2json` cannot know which attributes can be multi-valued or the types of each attribute. The default behaviour is to output the values of all attributes as JSON arrays even when only one value is present and to coerce each value to a number if and only if all values of that attribute are valid numbers. Otherwise values are strings.

See the `--flatten` and `--type` options below to change this behaviour.

Options
-------

-h, --help

:   Prints brief usage information.

-f, --flatten [ATTRIBUTE[,ATTRIBUTE...]]

:   For each ATTRIBUTE (or all attributes if none are given) if all values of each attribute have only a single
    value then flatten them to a single value

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
