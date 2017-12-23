require 'yaml'
require 'dnsmadeeasy'
require 'hashie/extensions/symbolize_keys'
require 'sym'
require_relative 'api_keys'

module DnsMadeEasy
  module Credentials

    class YamlFile
      attr_accessor :filename, :account, :mash

      def initialize(filename: default_credentials_path)
        self.filename = filename
        parse! if exist?
      end

      def keys(account_name: nil, encryption_key: nil)
        return nil unless exist?
        return nil if mash.nil?

        creds = if mash.accounts.is_a?(Array)
                  account = if account_name
                              mash.accounts.find { |a| a.name == account_name.to_s }
                            else
                              mash.accounts.find { |a| a.default_account }
                            end

                  raise DnsMadeEasy::APIKeyAndSecretMissingError,
                        (account_name ? "account #{account_name} was not found" : 'default account does not exist') unless account

                  raise DnsMadeEasy::InvalidCredentialsFormatError,
                        'Expected account entry to have "credentials" key' unless account.credentials

                  account.credentials

                elsif mash.credentials
                  mash.credentials

                else
                  raise DnsMadeEasy::InvalidCredentialsFormatError,
                        'expected either "accounts" or "credentials" as the top-level key'
                end

        creds ? ApiKeys.new(creds.api_key,
                            creds.api_secret,
                            encryption_key || creds.encryption_key) : nil
      end

      def to_s
        "file #{filename}"
      end

      private

      def parse!
        self.mash = Hashie::Extensions::SymbolizeKeys.symbolize_keys(load_hash)
      end

      def exist?
        ::File.exist?(filename)
      end

      def contents
        ::File.read(filename)
      end

      def load_hash
        Hashie::Mash.new(YAML.load(contents))
      end

    end

  end
end
