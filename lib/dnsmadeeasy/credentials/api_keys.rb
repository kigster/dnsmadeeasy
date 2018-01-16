require 'yaml'
require 'dnsmadeeasy'
require 'hashie/extensions/mash/symbolize_keys'
require 'sym'
require 'sym/app'
require 'digest'

module DnsMadeEasy
  module Credentials
    #
    # Immutable instance with key and secret.
    #
    class ApiKeys
      API_KEY_REGEX = /^([0-9a-f]{8})-([0-9a-f]{4})-([0-9a-f]{4})-([0-9a-f]{4})-([0-9a-f]{12})$/

      attr_reader :api_key,
                  :api_secret,
                  :encryption_key,
                  :default,
                  :account

      include Sym

      def initialize(key, secret, encryption_key = nil, default: false, account: nil)
        raise InvalidCredentialKeys, "Key and Secret can not be nil" if key.nil? || secret.nil?

        @default      = default
        @account = account

        if !valid?(key, secret) && encryption_key
          @encryption_key = sym_resolve(encryption_key)
          @api_key    = decr(key, @encryption_key)
          @api_secret = decr(secret, @encryption_key)
        else
          @api_key    = key
          @api_secret = secret
        end

        raise InvalidCredentialKeys, "Key [#{api_key}] or Secret [#{api_secret}] has failed validation for its format" unless valid?
      end

      def sym_resolve(encryption_key)
        null_output = ::File.open('/dev/null', 'w')
        result = Sym::Application.new({ cache_passwords: true, key: encryption_key }, $stdin, null_output, null_output).execute
        if result.is_a?(Hash)
          raise InvalidCredentialKeys, "Unable to decrypt the data, error is: #{result[:exception]}"
        else
          result
        end
      end

      def to_s
        "<#{self.class.name}#key=[s#{rofl(api_key)}] secret=[#{rofl(api_secret)}] encryption_key=[#{rofl(encryption_key)}]>"
      end

      def rofl(key)
        Digest::SHA256::hexdigest(key) if key
      end

      def valid?(key = self.api_key, secret = self.api_secret)
        key &&
          secret &&
          API_KEY_REGEX.match(key) &&
          API_KEY_REGEX.match(secret)
      end

      def ==(other)
        other.is_a?(ApiKeys) &&
          other.valid? &&
          other.api_key == api_key &&
          other.api_secret == api_secret
      end

      alias eql? ==
    end
  end
end
