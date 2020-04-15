#!/usr/bin/env ruby
# frozen_string_literal: true

# vim: ft=ruby

require 'colored2'
require 'awesome_print'
require 'dnsmadeeasy'
require 'dnsmadeeasy/api/client'
require 'etc'

module DnsMadeEasy
  class Runner
    SUPPORTED_FORMATS = %w(json json_pretty yaml pp).freeze

    attr_accessor :format, :argv, :operation

    def initialize(argv = nil)
      self.argv = argv || ARGV.dup
      self.format = process_flags_format
    end

    def execute!
      if argv.empty? || argv.empty?
        print_help_message
      else
        configure_authentication
        self.operation = argv.shift.to_sym
        exit call_through_client(operation)
      end
    end

    private

    def call_through_client(method)
      result = DnsMadeEasy.client.send(method, *argv)
      case result
      when NilClass
        puts 'No records returned.'
      when Hashie::Mash
        print_formatted(result.to_hash, format)
      when Array
        print_formatted(result, format)
      else
        print_formatted(result, format)
      end
      0
    rescue ArgumentError => e
      sig = method_signature(e, method)
      print_signature(method, sig) if sig.shift == method.to_s
      print_error('Action', method.to_s.bold.yellow.to_s, 'has generated an error'.red, exception: e)
      1
    rescue NoMethodError => e
      print_error('Action', method.to_s.bold.yellow.to_s, 'is not valid.'.red)
      puts 'HINT: try running ' + 'dme operations'.bold.green + ' to see the list of valid operations.'
      2
    rescue Net::HTTPServerException => e
      print_error(exception: e)
      3
    end

    def print_error(*args, exception: nil)
      unless args.empty?
        puts <<~EOF
          #{'Error:'.bold.red} #{args.join(' ').red}
        EOF
      end

      if exception
        puts <<~EOF
          #{'Exception: '.bold.red}#{exception.inspect.red}
        EOF
      end
    end

    def print_signature(method, sig)
      puts <<~EOF
        #{'Error: '.bold.yellow}
        #{'You are missing some arguments for this operation:'.red}

        #{'Correct Usage: '.bold.yellow}
        #{method.to_s.bold.green} #{sig.join(' ').blue}

      EOF
    end

    def process_flags_format
      format = nil
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
      elsif argv.first =~ /^op(erations)?$/i
        print_supported_operations
        exit 0
      end
      format
    end

    def configure_authentication
      credentials_file = ENV['DNSMADEEASY_CREDENTIALS_FILE'] ||
        DnsMadeEasy::Credentials.default_credentials_path(user: Etc.getlogin)

      if ENV['DNSMADEEASY_API_KEY'] && ENV['DNSMADEEASY_API_SECRET']
        DnsMadeEasy.api_key = ENV['DNSMADEEASY_API_KEY']
        DnsMadeEasy.api_secret = ENV['DNSMADEEASY_API_SECRET']

      elsif credentials_file && ::File.exist?(credentials_file)
        keys = DnsMadeEasy::Credentials.keys_from_file(file: credentials_file)
        if keys
          DnsMadeEasy.api_key = keys.api_key
          DnsMadeEasy.api_secret = keys.api_secret
        end
      end

      if DnsMadeEasy.api_key.nil?
        print_error('API Key/Secret was not detected or read from file')
        puts('You can also set two environment variables: ')
        puts('    • DNSMADEEASY_API_KEY and ')
        puts('    • DNSMADEEASY_API_SECRET')
        exit 123
      end
    end

    def print_usage_message
      puts <<~EOF
          #{'Usage:'.bold.yellow}
                #{'# Execute an API call:'.dark}
                #{"dme [ #{SUPPORTED_FORMATS.map { |f| "--#{f}" }.join(' | ')} ] operation [ arg1 arg2 ... ] ".bold.green}

                #{'# Print suported operations:'.dark}
                #{'dme op[erations]'.bold.green}

      EOF
    end

    def print_help_message
      print_usage_message
      puts <<~EOF
        #{header 'Credentials'}
          Store your credentials in a YAML file
          #{DnsMadeEasy::Credentials.default_credentials_path(user: ENV['USER'])} as follows:

          #{'credentials:
            api_key: XXXX
            api_secret: YYYY'.bold.magenta}

          Or a multi-account version:

          #{'accounts:
            - name: production
              credentials:
                api_key: XXXX
                api_secret: YYYY
                encryption_key: my_key
            - name: development
              default_account: true
              credentials:
                api_key: ZZZZ
                api_secret: WWWW'.bold.magenta}

        #{header 'Examples:'}
           #{'dme domain moo.com
           dme --json domain  moo.com

           dme all            moo.com
           dme find_all       moo.com A       www
           dme find_first     moo.com CNAME   vpn-west
           dme update_record  moo.com www  A  11.3.43.56
           dme create_record  moo.com ftp  CNAME  www.moo.com.

           dme --yaml find_first moo.com CNAME vpn-west'.green}

      EOF
      exit 1
    end

    def header(message)
      message.bold.yellow.to_s
    end

    def print_supported_operations
      puts <<~EOF
        #{header 'Actions:'}
          Checkout the README and RubyDoc for the arguments to each operation,
          which is basically a method on a DnsMadeEasy::Api::Client instance.
          #{'http://www.rubydoc.info/gems/dnsmadeeasy/DnsMadeEasy/Api/Client'.blue.bold.underlined}

        #{header 'Valid Operations Are:'}
          #{DnsMadeEasy::Api::Client.public_operations.join("\n  ").green.bold}
      EOF
    end

    def print_formatted(result, format = nil)
      if format
        if format.to_sym == :json_pretty
          puts JSON.pretty_generate(result)
        elsif format.to_sym == :pp
          require 'pp'
          pp result
        else
          m = "to_#{format}".to_sym
          puts result.send(m) if result.respond_to?(m)
        end
      else
        ap(result, indent: 10)
      end
    end

    # e.backtrack.first looks like this:
    # ..../dnsmadeeasy/lib/dnsmadeeasy/api/client.rb:143:in `create_a_record'
    def method_signature(e, method)
      file, line, call_method = e.backtrace.first.split(':')
      call_method = call_method.gsub(/[']/, '').split('`').last
      if call_method && call_method.to_sym == method.to_sym
        source_line = File.open(file).to_a[line.to_i - 1].chomp!
        if source_line =~ /def #{method}/
          signature = source_line.strip.gsub(/,/, '').split(/[ ()]/)
          signature.shift # remove def
          return signature.reject { |a| a =~ /^([={}\)\(])*$/ }
        end
      end
      []
    rescue StandardError
      []
    end

    def puts(*args)
      super(*args)
    end
  end
end
