require 'rdf'
require 'optparse'
begin
  gem 'linkeddata'
  require 'linkeddata'
rescue
  # Silently load without linkeddata
end

class OptionParser
  def options; @options || {}; end
  def options=(value); @options = value; end
end

module RDF
  class CLI
    
    COMMANDS = {
      "count"       => lambda do |argv, opts|
        count = 0
        self.parse(*argv, opts) do |reader|
          reader.each_statement do |statement|
            count += 1
          end
        end
        puts count
      end,
      "lenghts"     => lambda do |argv, opts|
        self.parse(*argv, opts) do |reader|
          reader.each_statement do |statement|
            puts statement.to_s.size
          end
        end
      end,
      "objects"     => lambda do |argv, opts|
        self.parse(*argv, opts) do |reader|
          reader.each_statement do |statement|
            puts statement.object.to_ntriples
          end
        end
      end,
      "predicates"   => lambda do |argv, opts|
        self.parse(*argv, opts) do |reader|
          reader.each_statement do |statement|
            puts statement.predicate.to_ntriples
          end
        end
      end,
      "subjects"   => lambda do |argv, opts|
        self.parse(*argv, opts) do |reader|
          reader.each_statement do |statement|
            puts statement.subject.to_ntriples
          end
        end
      end
    }
    
    ##
    # @return [String]
    def self.basename() File.basename($0) end

    ##
    # @yield  [options]
    # @yieldparam [OptionParser]
    # @return [OptionParser]
    def self.options(&block)
      options = OptionParser.new
      opts = options.options = {
        :base_uri       => nil,
        :canonicalize   => false,
        :debug          => false,
        :evaluate       => nil,
        :format         => nil,
        :output         => STDOUT,
        :output_format  => :ntriples,
        :quiet          => false,
        :validate       => false,
      }

      # Command-specific options
      if block_given?
        case block.arity
          when 1 then block.call(options)
          else options.instance_eval(&block)
        end
      end
      options.banner ||= "Usage: #{self.basename} [options] command [args...]"

      options.on('--canonicalize', 'Canonicalize input.') do
        opts[:canonicalize] = true
      end

      options.on('-d', '--debug',   'Enable debug output for troubleshooting.') do
        opts[:debug] = $DEBUG = true
      end

      options.on("-e", "--evaluate STRING", "Evaluate argument as RDF input, if no files are specified") do |arg|
        opts[:evaluate] = arg
      end

      options.on("--input-format FORMAT", "Format of input file, uses heuristic if not specified") do |arg|
        opts[:format] = arg.downcase.to_sym
      end

      options.on("-o", "--output FILE", "File to write output, defaults to STDOUT") do |arg|
        opts[:output] = File.open(arg, "w")
      end

      options.on("--output-format FORMAT", "Format of output file, defaults to NTriples") do |arg|
        opts[:output_format] = arg.downcase.to_sym
      end

      options.on('-q', '--quite', 'Quiet output.') do
        opts[:quiet] = true
      end

      options.on('--uri URI', 'Base URI of input file, defaults to the filename.') do |arg|
        opts[:base_uri] = arg
      end

      options.on('--validate', 'Validate input file.') do
        opts[:validate] = true
      end

      options.on_tail("-h", "--help", "Show this message") do
        puts options
        puts "Available commands:\n\t#{self.commands.join("\n\t")}"
        exit
      end
      
      begin
        options.parse!
      rescue OptionParser::InvalidOption => e
        abort e
      end
      
      options
    end

    ##
    # @param  [String] command
    # @param  [Array<String>] args
    # @return [Boolean]
    def self.exec_command(command, args, options = {})
      unless COMMANDS.has_key?(command)
        abort "#{File.basename($0)}: unknown command `#{command}'"
      end
      
      COMMANDS[command].call(args, options)
    end
    
    ##
    # @return [Array<String>] list of executable commands
    def self.commands
      COMMANDS.keys
    end

    ##
    # Parse each file, STDIN or specified string in options[:evaluate] yielding
    # a reader
    #
    # @param  [Array<String>] files
    # @yield  [reader]
    # @yieldparam [RDF::Reader]
    # @return [nil]
    def self.parse(*files, &block)
      options = files.last.is_a?(Hash) ? files.pop : {}
      
      if files.empty?
        # If files are empty, either use options[:execute]
        RDF::Reader.new(options[:input] ? StringIO.new(options[:evaluate], options) : STDIN) {|reader| yield(reader)}
      else
        files.each do |file|
          RDF::Reader.open(file, options) {|reader| yield(reader)}
        end
      end
    end
    
    ##
    # @param  [String] msg
    # @return [void]
    def self.abort(msg)
      Kernel.abort "#{basename}: #{msg}"
    end
  end
end
