require 'yaml'

module DnsMadeEasy
  # Credentials file should look like this:
  #
  # Usage:
  #
  # Example 1. Assuming file ~/.dnsmadeeasy/credentials.yml exists:
  #
  #       DnsMadeEasy::Credentials.exist? #=> true
  #       creds = DnsMadeEasy::Credentials.load
  #
  #       creds.api_key #=> key
  #       creds.api_secret #=> secret
  #
  #
  # Example 2. Assuming another file: ~/.private/dnsmadeeasy.yml:
  #
  #       DnsMadeEasy::Credentials.exist? #=> false
  #       DnsMadeEasy::Credentials.exist?('~/.private/dnsmadeeasy.yml') #=> true
  #
  #       creds = DnsMadeEasy::Credentials.load('~/.private/dnsmadeeasy.yml')
  #       creds.api_key #=> key
  #       creds.api_secret #=> secret
  #
  #
  class Credentials < Hash
    #DEFAULT_CREDENTIALS_FILE = File.expand_path('~/.dnsmadeeasy/credentials.yml').freeze

    class CredentialsFileNotFound < StandardError
    end

    #
    # Class Methods
    #
    #
    class << self
      # Default credential file that's used if no argument is passed.
      attr_accessor :default_credentials_file

      def exist?(file = default_credentials_file)
        File.exist?(file)
      end

      def load(file = default_credentials_file)
        validate_argument(file)

        new.tap do |local|
          local.merge!(parse_file(file)) if exist?(file)
          local.symbolize!
        end
      end


      private

      def validate_argument(file)
        unless file && File.exist?(file)
          raise CredentialsFileNotFound, "File #{file} could not be found"
        end
      end


      def parse_file(file)
        YAML.load(read_file(file))
      end


      def read_file(file)
        File.read(file)
      end
    end

    # Set the default
    self.default_credentials_file ||= File.expand_path('~/.dnsmadeeasy/credentials.yml').freeze

    # Instance Methods
    # NOTE: we are subclassing Hash, which isn't awesome, but gets the job done.

    def symbolize(param_hash = self)
      Hash.new.tap { |hash|
        param_hash.each_pair do |key, key_value|
          value = recurse_if_needed(key_value)
          symbolize_key(hash, key, value)
        end
      }
    end

    public

    def valid?
      api_key && api_secret
    end


    def symbolize!
      hash = symbolize(self)
      clear
      merge!(hash)
    end


    def api_key
      credentials && credentials[:api_key]
    end


    def api_secret
      credentials && credentials[:api_secret]
    end


    private

    def symbolize_key(hash, key, value)
      case key
        when String, Symbol
          hash[key.to_sym] = value
        else
          hash[key.to_s.to_sym] = value
      end
    end


    def recurse_if_needed(key_value)
      key_value.is_a?(Hash) ? symbolize(key_value) : key_value
    end


    def credentials
      self[:credentials] || {}
    end


  end
end
