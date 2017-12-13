module DnsMadeEasy
  API_BASE_URL_PRODUCTION = 'https://api.dnsmadeeasy.com/V2.0'
  API_BASE_URL_SANDBOX    = 'https://sandboxapi.dnsmadeeasy.com/V2.0'
end

require 'dnsmadeeasy/credentials'
require 'dnsmadeeasy/api/client'

module DnsMadeEasy
  class Error < StandardError;  end
  class AuthenticationError < Error; end
  class APIKeyAndSecretMissingError < Error; end

  class << self
    attr_accessor :api_key, :api_secret

    def credentials=(file)
      @creds = ::DnsMadeEasy::Credentials.load(file)
      if @creds && @creds.valid?
        configure do |config|
          config.api_key = @creds.api_key
          config.api_secret = @creds.api_secret
        end
      end
    end

    def configure
      yield(self) if block_given?
    end

    def client(**options)
      @client ||= create_client(false, **options)
    end


    def sandbox_client(**options)
      @sandbox_client ||= create_client(true, **options)
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

    def default!
      assign_default_credentials
    end


    def assign_default_credentials
      if Credentials.exist?
        self.credentials = Credentials.default_credentials_file
      end
    end

    private

    def create_client(sandbox = false, **options)
      default! unless api_key && api_secret
      raise APIKeyAndSecretMissingError, 'Please set #api_key and #api_secret' unless api_key && api_secret
      ::DnsMadeEasy::Api::Client.new(api_key, api_secret, sandbox, **options)
    end
  end

end
