# ldif2json

Convert LDIF output from `ldapsearch` or `slapcat` to JSON suitable for easier processing with tools like `jq`, `mlr` or other scripts.

## Installation

[Install the Crystal compiler (and shards tool)](https://crystal-lang.org/install/) then run

    make install

## Usage

    ldapsearch [ options ] | ldif2json >data.json
    
### Options

By default `ldif2json` returns all attributes as arrays, even if only one value is present, and sets the output type to `auto`, meaning that if all the values seeing for an attribute are numbers then they are output as numbers, otherwise as strings.
* `--flatten` - if an attribute has only a single value (or is missing) for all records, output it as single values instead of as arrays
* `--join=SEPARATOR` - join multi-value attributes with SEPARATOR and return a string (`,` is not recommended since it is a component of DNs)
* `--type=attribute:type` - force the given attribute to have the given type. Valid types are:
  * `auto` - use `number` if all values are numbers, otherwise `string`
  * `string` - always return strings
  * `number` - always return numbers; if a value is not a valid number, return `0`
  * `number!` - always return numbers; if any value is not a number, exit with status 2
  * `bool` - always return either `true` or `false`; if a value is the empty string or a number that evaluates to zero then `false` otherwise `true`
  * `numbool` - return `true` for non-zero numerics, `false` for zero and exit status 2 for anything else

## Contributing

1. Fork it (<https://github.com/your-github-user/ldif2json/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [joatca](https://github.com/joatca) - creator and maintainer
