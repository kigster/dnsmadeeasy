module DnsMadeEasy
  API_BASE_URL_PRODUCTION = 'https://api.dnsmadeeasy.com/V2.0'
  API_BASE_URL_SANDBOX    = 'https://sandboxapi.dnsmadeeasy.com/V2.0'
end

require 'dnsmadeeasy/version'
require 'dnsmadeeasy/credentials'
require 'dnsmadeeasy/api/client'

module DnsMadeEasy
  class Error < StandardError;
  end
  class AuthenticationError < Error;
  end
  class APIKeyAndSecretMissingError < Error;
  end
  class InvalidCredentialKeys < Error;
  end
  class AbstractMethodError < Error;
  end
  class InvalidCredentialsFormatError < Error;
  end
  class NoSuchAccountError < Error;
  end
  class NoDomainError < Error;
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
        file:           file || ::DnsMadeEasy::Credentials.default_credentials_path(user: ENV['USER']),
        account:        account,
        encryption_key: encryption_key)
      if credentials
        configure do |config|
          config.api_key    = credentials.api_key
          config.api_secret = credentials.api_secret
        end
      else
        raise APIKeyAndSecretMissingError, "Unable to load valid api keys from #{file}!"
      end
    end

    def credentials_from_file(file: DnsMadeEasy::Credentials.default_credentials_path,
                              account: nil,
                              encryption_key: nil)

      DnsMadeEasy::Credentials.keys_from_file file:           file,
                                              account:        account,
                                              encryption_key: encryption_key
    end

    def api_key=(value)
      self.default_api_key = value
    end

    def api_secret=(value)
      self.default_api_secret = value
    end

    def client(**options)
      @client ||= create_client(false, **options)
    end

    def sandbox_client(**options)
      @sandbox_client ||= create_client(true, **options)
    end

    def create_client(sandbox = false,
                      api_key: self.default_api_key,
                      api_secret: self.default_api_secret,

                      **options)
      raise APIKeyAndSecretMissingError, 'Please set #api_key and #api_secret' unless api_key && api_secret
      ::DnsMadeEasy::Api::Client.new(api_key, api_secret, sandbox, **options)
    end

    # Basically delegate it all to the Client instance
    # if the method call is supported.
    #
    def method_missing(method, *args, &block)
      if client.respond_to?(method)
        client.send(method, *args, &block)
      else
        super(method, *args, &block)
      end
    end
  end
end
