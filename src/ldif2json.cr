# This file is part of ldif2json.

# ldif2json is free software: you can redistribute it and/or modify it under the terms of the GNU General Public
# License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any
# later version.

# ldif2json is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.

# You should have received a copy of the GNU General Public License along with ldif2json.  If not, see
# <https://www.gnu.org/licenses/>.

require "./conf"
require "./records"

module Ldif2json
  VERSION = "0.1.0"

  enum Mode
    Normal
    Flatten
    Join
  end

  enum Type
    Auto
    String
    Number0
    NumberErr
  end

  class NormalError < Exception
  end

  begin
    
    config = Conf.new
    records = Records.new
    Record.set_config(config)

    key, value = "", "" # current record, maybe not yet processed
    encoded = false # is the current record in encoded format?
    
    ARGF.each_line do |line|
      case line.chomp
      when /^#/ # comment, do nothing
        next
      when /^ (.+)$/ # continuation line
        value += $1
      when /^(\w+):: (.*)$/ # base-64 encoded record
        records.add_value(key, value, encoded) # get the current record out of the way, if any
        key, value = $1, $2
        encoded = true
      when /^(\w+): (.+)$/ # regular line line
        records.add_value(key, value, encoded) # get the current record out of the way, if any
        key, value = $1, $2
        encoded = false
      when "" # empty line, end of record
        records.end_record(key, value, encoded) # get the current record out of the way, if any
        key, value = "", ""
      end
    end

    records.end_record(key, value, encoded) # catch the last one

    records.dump(config, STDOUT)

  rescue e : NormalError

    STDERR.puts "#{PROGRAM_NAME}: #{e.message}"
    exit(1)

  end

end
