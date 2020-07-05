require "option_parser"
require "json"
require "set"
require "base64"

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
    Number
    NumberErr
  end

  class NormalError < Exception
  end

  class Conf

    property mode, join_string, coercions
    
    @mode : Mode
    @join_string : String
    @coercions : Hash(String, Type)

    def initialize
      @mode = Mode::Normal
      @join_string = ":" # the default is not used at the moment
      @coercions = Hash(String, Type).new(Type::Auto) # default value is auto so we don't need to special case a missing type option
      
      OptionParser.new do |opts|
        opts.banner = "Usage: #{PROGRAM_NAME} [options]\n\nValid TYPE values are:\nauto (coerce to integers if possible, otherwise floats, otherwise string)\nstring (always interpret as string)\nnumber (coerce to a number, 0 if invalid)\nnumber! (coerce to a number, error if any invalid)\n"

        opts.on("-f", "--flatten", "flatten each attribute to a single element if no records are multi-value") do |v|
          @mode = Mode::Flatten
        end

        opts.on("-jSEP", "--join=SEP", "join multi-value attributes with SEP") do |v|
          @mode = Mode::Join
          @join_string = v
        end

        opts.on("-t=ATTRIBUTE:TYPE", "--type=ATTRIBUTE:TYPE", "force ATTRIBUTE to always be coerced to TYPE, otherwise exit with error") do |v|
          if v =~ /^([\S:]+):([\S:]+)$/
            attrib, coercion = $1, $2
            @coercions[attrib] = case coercion
                                 when "auto"
                                   Type::Auto
                                 when "string"
                                   Type::String
                                 when "number"
                                   Type::Number
                                 when "number!"
                                   Type::NumberErr
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

    end

    # return true if we should attempt to do any sort of int processing for this attribute
    def do_coercion(attrib : String)
      case @coercions[attrib]
      when Type::Number, Type::NumberErr, Type::Auto
        true
      else
        false
      end
    end

  end

  # an individual record, based on a hash but with extra functionality
  class Record

    @@can_be_coerced = Hash(String, Bool).new(true)
    @@can_be_flattened = Hash(String, Bool).new(true)

    def self.set_config(config : Conf)
      @@config = config
      @@can_be_coerced = Hash(String, Bool).new(config.mode != Mode::Join)
      @@can_be_flattened = Hash(String, Bool).new(config.mode != Mode::Join)
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
      if @@can_be_coerced[key]
        #if key == "uidNumber"
          #puts "#{key} #{@@can_be_coerced[key]}"
        #end
        @coerced_values[key]
      else
        @original_values[key]
      end
    end
    
    def []=(key : String, value : JSON::Any)

      #puts "set #{key} to #{value}"

      @original_values[key].as_a << value

      if @@can_be_flattened[key]
        if @original_values[key].as_a.size > 1
          @@can_be_flattened[key] = false
        end
      end
      
      if config.do_coercion(key) && @@can_be_coerced[key]
        case config.coercions[key]
        when Type::Number # coerce to a number or zero if it's not a valid number
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
                  # don't rescue this, let it propagate all the way up so we can return an error
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
            @@can_be_coerced[key] = false
          end
        end
      end
    end

    def flatten
      @original_values.each_key.select { |attrib| @@can_be_flattened[attrib] }.each do |attrib|
        @original_values[attrib] = @original_values[attrib].as_a.first
        @coerced_values[attrib] = @coerced_values[attrib].as_a.first if @@can_be_coerced[attrib]
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
  
  class Records

    @current : Record
    
    def initialize
      @records = Array(Record).new
      @current = new_record
      @attrib_names = Set(String).new
    end

    # this adds values from the "raw" LDIF so everything starts off being added as a String
    def add_value(key : String, value : String, encoded : Bool)
      #puts "add_value key #{key} value #{value} encoded #{encoded}"
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
      #puts "end_record keys #{@current.keys.inspect}"
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

  end

end
