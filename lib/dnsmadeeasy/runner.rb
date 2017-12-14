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
      if argv.empty? || argv.size < 2
        print_help_message
      else
        self.operation = argv.shift.to_sym
        call_through_client(operation)
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
      rescue NoMethodError
        puts 'Action '.red + "#{method.to_s.bold.yellow} " + 'is not valid.'.red
      rescue Net::HTTPServerException => e
        puts "Error — #{e.message.red}".bold.red
      end
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
  #{'dme operations'.bold.green}

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

#{'Valid Operations Are:'.bold.yellow}
    Checkout the README and RubyDoc for the arguments to each operation,
    which is basically a method on a DnsMadeEasy::Api::Client instance.

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
  end
end



