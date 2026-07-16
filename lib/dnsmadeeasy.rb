# frozen_string_literal: true

module DnsMadeEasy
  API_BASE_URL_PRODUCTION = 'https://api.dnsmadeeasy.com/V2.0'
  API_BASE_URL_SANDBOX    = 'https://api.sandbox.dnsmadeeasy.com/V2.0'
end

require 'dnsmadeeasy/version'
require 'dnsmadeeasy/types'
require 'dnsmadeeasy/credentials'
require 'dnsmadeeasy/api/client'
require 'dnsmadeeasy/cli/launcher'
require 'dnsmadeeasy/zone/record'
require 'dnsmadeeasy/zone/provider_record'
require 'dnsmadeeasy/zone/record_set'
require 'dnsmadeeasy/zone/parser'

module DnsMadeEasy
  class Error < StandardError
  end

  class AuthenticationError < Error
  end

  class APIKeyAndSecretMissingError < Error
  end

  class InvalidCredentialKeys < Error
  end

  class AbstractMethodError < Error
  end

  class InvalidCredentialsFormatError < Error
  end

  class NoSuchAccountError < Error
  end

  class NoDomainError < Error
  end

  class << self
    attr_accessor :default_api_key,
                  :default_api_secret

    def configure
      yield(self) if block_given?
    end

    def configure_from_file(file = nil,
                            account = nil,
                            encryption_key = nil)
      credentials = ::DnsMadeEasy::Credentials.keys_from_file(
        file: file || ::DnsMadeEasy::Credentials.default_credentials_path(user: ENV.fetch('USER', nil)),
        account: account,
        encryption_key: encryption_key
      )
      raise APIKeyAndSecretMissingError, "Unable to load valid api keys from #{file}!" unless credentials

      configure do |config|
        config.api_key    = credentials.api_key
        config.api_secret = credentials.api_secret
      end
    end

    def credentials_from_file(file: DnsMadeEasy::Credentials.default_credentials_path,
                              account: nil,
                              encryption_key: nil)
      DnsMadeEasy::Credentials.keys_from_file file: file,
                                              account: account,
                                              encryption_key: encryption_key
    end

    def api_key=(value)
      self.default_api_key = value
    end

    def api_key
      default_api_key
    end

    def api_secret=(value)
      self.default_api_secret = value
    end

    def api_secret
      default_api_secret
    end

    def client(**)
      @client ||= create_client(false, **)
    end

    def sandbox_client(**)
      @sandbox_client ||= create_client(true, **)
    end

    def create_client(sandbox = false,
                      api_key: default_api_key,
                      api_secret: default_api_secret,

                      **)
      raise APIKeyAndSecretMissingError, 'Please set #api_key and #api_secret' unless api_key && api_secret

      ::DnsMadeEasy::Api::Client.new(api_key, api_secret, sandbox, **)
    end

    # Basically delegate it all to the Client instance
    # if the method call is supported.
    #
    def method_missing(method, ...)
      if client.respond_to?(method)
        client.send(method, ...)
      else
        super
      end
    end

    def respond_to_missing?(method, include_private = false)
      client.respond_to?(method, include_private) || super
    rescue APIKeyAndSecretMissingError
      super
    end
  end
end
