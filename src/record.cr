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

module Ldif2json

  # an individual record, based on a hash but with extra functionality
  class Record

    def self.set_config(config : Conf)
      @@config = config
    end

    def initialize
      @original_values = Hash(String, JSON::Any).new { |h, k| h[k] = JSON::Any.new([] of JSON::Any) }
      @coerced_values = Hash(String, JSON::Any).new { |h, k| h[k] = JSON::Any.new([] of JSON::Any) }
    end

    def config
      # this feels dirty but we're fine if no mistakes are made ;-)
      if @@config.nil?
        raise RuntimeError.new("attempt to access config before set")
      else
        @@config.as(Conf)
      end
    end
      
    delegate size, to: @original_values
    delegate has_key?, to: @original_values
    delegate each_key, to: @original_values
    delegate to_json, to: @original_values

    # if an attribute is coercible then return the coerced values, otherwise return the base string values
    def [](key : String)
      if config.can_be_coerced[key]
        #if key == "uidNumber"
          #puts "#{key} #{config.can_be_coerced[key]}"
        #end
        @coerced_values[key]
      else
        @original_values[key]
      end
    end
    
    def []=(key : String, value : JSON::Any)

      #puts "set #{key} to #{value}"

      @original_values[key].as_a << value

      if config.can_be_flattened[key]
        if @original_values[key].as_a.size > 1
          config.can_be_flattened[key] = false
        end
      end
      
      if config.can_be_coerced[key]
        case config.coercions[key]
        when Type::Number0 # coerce to a number or zero if it's not a valid number
          v = begin
                value.as_s.to_i64
              rescue ArgumentError
                # OK, try a float
                begin
                  value.as_s.to_f64
                rescue ArgumentError
                  0_i64
                end
              end
          @coerced_values[key].as_a << JSON::Any.new(v)
        when Type::NumberErr
          # coerce to a number and if not possible raise an exception
          begin
            v = begin
                  value.as_s.to_i64
                rescue ArgumentError
                  # don't rescue this, let it propagate up so we can return an error
                  value.as_s.to_f64
                end
            @coerced_values[key].as_a << JSON::Any.new(v)
          rescue ArgumentError
            raise NormalError.new("value \"#{value}\" for attribute \"#{key}\" is not a valid number")
          end
        when Type::Auto
          # coerce to a number and if not possible mark it as not coercible and do nothing else
          begin
            v = begin
                  value.as_s.to_i64
                rescue ArgumentError
                  # don't rescue this, let it propagate up one
                  value.as_s.to_f64
                end
            @coerced_values[key].as_a << JSON::Any.new(v)
          rescue ArgumentError
            #puts "cannot coerce #{key} because of value #{value}"
            config.can_be_coerced[key] = false
          end
        end
      end
    end

    def flatten
      @original_values.each_key.select { |attrib| config.can_be_flattened[attrib] }.each do |attrib|
        @original_values[attrib] = @original_values[attrib].as_a.first
        @coerced_values[attrib] = @coerced_values[attrib].as_a.first if config.can_be_coerced[attrib]
      end
    end

    def join(attrib : String)
      @original_values[attrib] = JSON::Any.new(@original_values[attrib].as_a.map { |v| v.as_s }.join(config.join_string))
    end

    def dump(io : IO)
      builder = JSON::Builder.new(io)
      builder.start_document
      builder.start_object
      @original_values.keys.each do |attrib|
        builder.field(attrib, self[attrib])
      end
      builder.end_object
      builder.end_document
      io << "\n"
    end

  end

end
