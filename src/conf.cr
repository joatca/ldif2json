# This file is part of gls.

# gls is free software: you can redistribute it and/or modify it under the terms of the GNU General Public
# License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any
# later version.

# gls is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.

# You should have received a copy of the GNU General Public License along with gls.  If not, see
# <https://www.gnu.org/licenses/>.

require "option_parser"

module Ldif2json

  class Conf

    property mode, join_string, coercions, can_be_coerced, can_be_flattened
    
    @mode : Mode
    @join_string : String
    @coercions : Hash(String, Type)
    @can_be_coerced : Hash(String, Bool)
    @can_be_flattened : Hash(String, Bool)

    def new_boolhash(default : Bool)
      Hash(String, Bool).new(default)
    end
    
    def initialize
      @mode = Mode::Normal
      @join_string = ":" # the default is not used at the moment
      @coercions = Hash(String, Type).new(Type::Auto) # default value is auto so we don't need to special case a missing type option
      @can_be_coerced = new_boolhash(true)
      @can_be_flattened = new_boolhash(false)
      
      OptionParser.new do |opts|
        opts.banner = "Usage: #{PROGRAM_NAME} [options]\n\nValid TYPE values are:\nauto (coerce to integers if possible, otherwise floats, otherwise string)\nstring (always interpret as string)\nnumber0 (coerce to a number, 0 if invalid)\nnumber (coerce to a number, error if any invalid)\n"

        opts.on("-f [ATTRIBUTES]", "--flatten [ATTRIBUTES]", "flatten each given attribute (or all attributes) to a single element if no records are multi-value") do |v|
          raise NormalError.new("cannot specify both flatten and join") unless @mode == Mode::Normal
          @mode = Mode::Flatten
          if v.size == 0 # no argument passed
            @can_be_flattened = new_boolhash(true) # override the false default
          else
            v.split(',').each do |attrib|
              @can_be_flattened[attrib] = true
            end
          end
        end

        opts.on("-jSEP", "--join=SEP", "join multi-value attributes with SEP (--type ignored)") do |v|
          raise NormalError.new("cannot specify both flatten and join") unless @mode == Mode::Normal
          raise NormalError.new("join string should be a single character, not \"#{v}\"") if v.size > 1
          @mode = Mode::Join
          @join_string = v
          # override the true defaults from above
          @can_be_coerced = new_boolhash(false)
          @can_be_flattened = new_boolhash(false)
        end

        opts.on("-t=ATTRIBUTE:TYPE", "--type=ATTRIBUTE:TYPE", "force ATTRIBUTE to always be coerced to TYPE, otherwise exit with error") do |v|
          if v =~ /^([\S:]+):([\S:]+)$/
            attrib, coercion = $1, $2
            case coercion
            when "auto"
              # do nothing, default is Type::Auto
            when "string"
              @coercions[attrib] = Type::String
              @can_be_coerced[attrib] = false # no point trying to coerce
            when "number0"
              @coercions[attrib] = Type::Number0
            when "number"
              @coercions[attrib] = Type::NumberErr
            else
              raise NormalError.new("unrecognised coercion \"#{coercion}\"")
            end
          end
        end

        opts.on("-h", "--help", "show this help") do
          puts opts
          exit
        end
        
      end.parse

      raise NormalError.new("cannot set types in join mode") if @mode == Mode::Join && @coercions.size > 0
      
    end

  end

end
