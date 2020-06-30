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
    Integer
    IntegerErr
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
        opts.banner = "Usage: #{PROGRAM_NAME} [options]\n\nValid TYPE values are:\nauto (coerce to integers if possible, otherwise floats, otherwise string)\nstring (always interpret as string)\nnumber (coerce to a floating-point number, 0.0 if invalid)\nnumber! (coerce to a floating-point number, error if any invalid)\ninteger (coerce to an integer, 0 if invalid)\ninteger! (coerce to an integer, error if any invalid)\n"

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
                                 when "integer"
                                   Type::Integer
                                 when "integer!"
                                   Type::IntegerErr
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

    # return true if any pre-processing is required, that is, --join or --flatten is specified or any attribute type is *not* string
    def preprocess(for_attribs : Set(String))
      return true unless @mode == Mode::Normal
      for_attribs.any? { |attrib| @coercions[attrib] != Type::String }
    end
    
  end
  
  class Records

    @current : Hash(String, JSON::Any)
    
    def initialize
      @records = Array(Hash(String, JSON::Any)).new
      @current = new_record
      @attrib_names = Set(String).new
      @has_multiple = Hash(String, Bool).new(false)
      @only_numeric = Hash(String, Bool).new(true)
    end

    # this adds values from the "raw" LDIF so everything starts off being added as a String
    def add_value(key : String, value : String, encoded : Bool)
      #puts "add_value key #{key} value #{value} encoded #{encoded}"
      if key.size > 0
        @current[key].as_a << JSON::Any.new(encoded ? Base64.decode_string(value) : value)
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
      Hash(String, JSON::Any).new { |h, k| h[k] = JSON::Any.new([] of JSON::Any) }
    end
  
    def dump(config : Conf, io : IO)
      if config.preprocess(@attrib_names)
        if config.mode == Mode::Join # everything is treated as a string and joined
          @records.each do |rec|
            rec.each_key do |attrib|
              rec[attrib] = JSON::Any.new(rec[attrib].as_a.map { |v| v.as_s }.join(config.join_string))
            end
          end
        else
          # either normal mode or flatten mode; in either case we coerce the types first; do each attribute first
          @attrib_names.each do |attrib|
            recs = @records.select { |rec| rec.has_key?(attrib) }
            case config.coercions[attrib]
            when Type::Number
              # coerce to a float where non-numeric strings evaluate to 0.0
              recs.each do |rec|
                newrec = rec[attrib].as_a.map { |v|
                  v = begin
                        v.as_s.to_f
                      rescue e : ArgumentError
                        0.0 # allow random strings to eval to zero
                      end
                  JSON::Any.new(v)
                }
                rec[attrib] = JSON::Any.new(newrec)
              end
            when Type::NumberErr
              begin
                recs.each do |rec|
                  rec[attrib] = JSON::Any.new(rec[attrib].as_a.map { |v| JSON::Any.new(v.as_s.to_f) })
                end
              rescue e : ArgumentError
                raise NormalError.new("error coercing attribute #{attrib} to number: #{e.message}")
              end
            when Type::Integer
              # coerce to a float where non-numeric strings evaluate to 0.0
              recs.each do |rec|
                newrec = rec[attrib].as_a.map { |v|
                  v = begin
                        v.as_s.to_i64
                      rescue e : ArgumentError
                        0_i64 # allow random strings to eval to zero
                      end
                  JSON::Any.new(v)
                }
                rec[attrib] = JSON::Any.new(newrec)
              end
            when Type::IntegerErr
              recs.each do |rec|
                begin
                  rec[attrib] = JSON::Any.new(rec[attrib].as_a.map { |v| JSON::Any.new(v.as_s.to_i64) })
                rescue e : ArgumentError
                  raise NormalError.new("error coercing attribute #{attrib} to integer: #{e.message}")
                end
              end
            when Type::String
            # do nothing - it's already a string
            when Type::Auto
              # try to generate a new list with all-numeric attributes and replace the current ones with that; if
              # that raises an exception then do nothing
              begin
                recs.each do |rec|
                  rec[attrib] = JSON::Any.new(rec[attrib].as_a.map { |v| JSON::Any.new(v.as_s.to_i64) })
                end
              rescue e : ArgumentError
                # that's fine, try floats                
                begin
                  recs.each do |rec|
                    rec[attrib] = JSON::Any.new(rec[attrib].as_a.map { |v| JSON::Any.new(v.as_s.to_f) })
                  end
                rescue e : ArgumentError
                  # that's fine
                end
              end
            end
            # now that all values have been coerced, check if we can flatten them if required
            if config.mode == Mode::Flatten
              unless recs.any? { |rec| rec[attrib].as_a.size > 1 }
                recs.each do |rec|
                  rec[attrib] = rec[attrib].as_a.first
                end
              end
            end
          end
        end
        # now we have all the records coerced, if necessary
      end
      @records.each do |rec|
        io.puts rec.to_json
      end
    end
  
  end

  begin
    
    config = Conf.new
    records = Records.new

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
