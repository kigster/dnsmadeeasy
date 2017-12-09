module DnsMadeEasy
  API_BASE_URL_PRODUCTION = 'https://api.dnsmadeeasy.com/V2.0'
  API_BASE_URL_SANDBOX    = 'https://sandboxapi.dnsmadeeasy.com/V2.0'
end

require_relative 'dnsmadeeasy/api/client'

module DnsMadeEasy
  class Error < StandardError;  end
  class APIKeyAndSecretMissingError < Error; end

  class << self
    attr_accessor :api_key, :api_secret


    def configure
      yield(self) if block_given?
    end


    def client(**options)
      @client ||= create_client(false, **options)
    end


    def sandbox_client(**options)
      @sandbox_client ||= create_client(true, **options)
    end


    private

    def create_client(sandbox = false, **options)
      raise APIKeyAndSecretMissingError, 'Please set #api_key and #api_secret' unless api_key && api_secret
      ::DnsMadeEasy::Api::Client.new(api_key, api_secret, sandbox, **options)
    end

  end
end
