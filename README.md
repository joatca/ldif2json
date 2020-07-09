# ldif2json

Convert LDIF output from `ldapsearch` or `slapcat` to JSON suitable for easier processing with tools like `jq`, `mlr` or other scripts.

## Installation

[Install the Crystal compiler (and shards tool)](https://crystal-lang.org/install/) and optionally [Pandoc](https://pandoc.org/) if you need to edit the manpage, then run

    make
    sudo make install

## Usage

    ldapsearch [ options ] | ldif2json >data.json

## Documentation

See `doc/ldif2json.md`

## Example

    ldapsearch [options] 'uid=*' | ldif2json --flatten | jq 'select(.cn | tostring | test("Smith$")) | .dn'

## Contributing

1. Fork it (<https://github.com/your-github-user/ldif2json/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [joatca](https://github.com/joatca) - creator and maintainer
