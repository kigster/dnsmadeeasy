#!/usr/bin/env ruby

require 'colored2'
require 'awesome_print'
require 'dnsmadeeasy'
require 'dnsmadeeasy/api/client'


module DnsMadeEasy
  class Runner
    SUPPORTED_FORMATS = %w(json yaml)

    attr_accessor :format, :argv, :operation


    def initialize(argv = nil)
      self.argv = argv || ARGV.dup
      configure_authentication
      self.format = process_flags_format
    end


    def execute!
      if argv.empty? || argv.size < 1
        print_help_message
      else
        self.operation = argv.shift.to_sym
        exit call_through_client(operation)
      end
    end


    private

    def call_through_client(method)
      begin
        result = DnsMadeEasy.client.send(method, *argv)
        case result
          when NilClass
            puts 'No records returned.'
          when Hashie::Mash
            print_formatted(result.to_hash, format)
          when Array
            print_formatted(result.map(&:to_hash), format)
          else
            print_formatted(result, format)
        end
        0
      rescue ArgumentError => e
        sig = method_signature(e, method)
        (sig.shift == method.to_s) ?
          print_signature(method, sig) :
          print_error('Action', "#{method.to_s.bold.yellow}", 'has generated an error'.red, exception: e)
        1
      rescue NoMethodError
        print_error('Action', "#{method.to_s.bold.yellow}", 'is not valid.'.red)
        puts 'HINT: try running ' + 'dme operations'.bold.green + ' to see the list of valid operations.'
        2
      rescue Net::HTTPServerException => e
        print_error(exception: e)
        3
      end
    end


    def print_error(*args, exception: nil)
      unless args.empty?
        puts <<-EOF
#{'Error:'.bold.red} #{args.join(' ').red}
        EOF
      end

      if exception
        puts <<-EOF
#{'Exception: '.bold.red}#{exception.inspect.red}
        EOF
      end
    end


    def print_signature(method, sig)
      puts <<-EOF
#{'Error: '.bold.yellow}
  #{'You are missing some arguments for this operation:'.red}

#{'Correct Usage: '.bold.yellow}
  #{method.to_s.bold.green} #{sig.join(' ').blue }

      EOF
    end


    def process_flags_format
      if argv.first&.start_with?('--')
        format = argv.shift.gsub(/^--/, '')
        if format =~ /^h(elp)?$/i
          print_help_message
        end
        unless SUPPORTED_FORMATS.include?(format)
          puts "Error: format #{format.bold.red} is not supported."
          puts "Supported values are: #{SUPPORTED_FORMATS.join(', ')}"
          exit 1
        end
      elsif argv.first =~ /^ope?r?a?t?i?o?n?$/i
        print_supported_operations
        exit 0
      end
      format
    end


    def configure_authentication
      if ENV['DNSMADEEASY_API_KEY'] && ENV['DNSMADEEASY_API_SECRET']
        DnsMadeEasy.configure do |config|
          config.api_key    = ENV['DNSMADEEASY_API_KEY']
          config.api_secret = ENV['DNSMADEEASY_API_SECRET']
        end
      else
        DnsMadeEasy.credentials = (ENV['DNSMADEEASY_CREDENTIALS'] || DnsMadeEasy::Credentials.default_credentials_file)
      end
    end


    def print_usage_message
      puts <<-EOF
#{'Usage:'.bold.yellow}
  #{'# Execute an API call:'.dark}
  #{"dme [ #{SUPPORTED_FORMATS.map { |f| "--#{f}" }.join(' | ')} ] operation [ arg1 arg2 ... ] ".bold.green}

  #{'# Print suported operations:'.dark}
  #{'dme op[erations]'.bold.green}

      EOF
    end


    def print_help_message
      print_usage_message

      puts <<-EOF
#{'Credentials:'.bold.yellow}
  Store your credentials in a YAML file 
  #{DnsMadeEasy::Credentials.default_credentials_file} as follows:

  #{'credentials:
    api_key: XXXX
    api_secret: YYYY'.bold.magenta}

#{'Examples:'.bold.yellow}
   #{'dme domain moo.com 
   dme --json domain moo.com 
   dme find_all moo.com A www
   dme find_first moo.com CNAME vpn-west
   dme --yaml find_first moo.com CNAME vpn-west'.green}

      EOF
      exit 1
    end


    def print_supported_operations
      puts <<-EOF
#{'Actions:'.bold.yellow}      
  Checkout the README and RubyDoc for the arguments to each operation,
  which is basically a method on a DnsMadeEasy::Api::Client instance.
  #{'http://www.rubydoc.info/gems/dnsmadeeasy/DnsMadeEasy/Api/Client'.blue.bold.underlined}

#{'Valid Operations Are:'.bold.yellow}
  #{DnsMadeEasy::Api::Client.public_operations.join("\n  ").green.bold}

      EOF
    end


    def print_formatted(result, format = nil)
      if format
        puts result.send("to_#{format}".to_sym)
      else
        ap(result, indent: 10)
      end
    end


    # e.backtrack.first looks like this:
    # ..../dnsmadeeasy/lib/dnsmadeeasy/api/client.rb:143:in `create_a_record'
    def method_signature(e, method)
      file, line, call_method = e.backtrace.first.split(':')
      call_method             = call_method.gsub(/[']/, '').split('`').last
      if call_method && call_method.to_sym == method.to_sym
        source_line = File.open(file).to_a[line.to_i - 1].chomp!
        if source_line =~ /def #{method}/
          signature = source_line.strip.gsub(/,/, '').split(%r{[ ()]})
          signature.shift # remove def
          return signature.reject { |a| a =~ /^([={}\)\(])*$/ }
        end
      end
      []
    rescue
      []
    end
  end
end



