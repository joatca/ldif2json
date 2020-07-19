# This file is part of ldif2json.

# ldif2json is free software: you can redistribute it and/or modify it under the terms of the GNU General Public
# License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any
# later version.

# ldif2json is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.

# You should have received a copy of the GNU General Public License along with ldif2json.  If not, see
# <https://www.gnu.org/licenses/>.

require "json"
require "set"
require "base64"
require "./record"

module Ldif2json
  
  class Records

    @current : Record
    
    def initialize
      @records = Array(Record).new
      @current = new_record
      @attrib_names = Set(String).new
    end

    # this adds values from the "raw" LDIF so everything starts off being added as a String
    def add_value(key : String, value : String, encoded : Bool)
      if key.size > 0
        @current[key] = JSON::Any.new(encoded ? Base64.decode_string(value) : value)
        @attrib_names << key
      end
    end

    def end_record(key : String, value : String, encoded : Bool)
      add_value(key, value, encoded)
      if @current.size > 0
        @records << @current
        @current = new_record
      end
    end

    def new_record
      # all attributes start as multi-value and we may or may not flatten them later
      Record.new
    end
  
    def dump(config : Conf, io : IO)
      @records.each do |rec|
        case config.mode
        when Mode::Join # everything is treated as a string and joined
          rec.each_key do |attrib|
            rec.join(attrib)
          end
        when Mode::Flatten
          rec.flatten
        end
        rec.dump(io)
      end
    end
  
  end

end
