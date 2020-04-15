# frozen_string_literal: true

require 'yaml'
require 'dnsmadeeasy'
require 'hashie/extensions/symbolize_keys'
require 'sym'
require_relative 'api_keys'

module DnsMadeEasy
  module Credentials
    class YamlFile
      attr_accessor :filename, :account, :mash

      def initialize(file: default_credentials_path)
        self.filename = file
        parse! if exist?
      end

      def keys(account: nil, encryption_key: nil)
        return nil unless exist?
        return nil if mash.nil?

        creds = if mash.accounts.is_a?(Array)
                  credentials_from_array(mash.accounts, account&.to_s)

                elsif mash.credentials
                  mash.credentials

                else
                  raise DnsMadeEasy::InvalidCredentialsFormatError,
                        'expected either "accounts" or "credentials" as the top-level key'
                end

        return nil unless creds

        ApiKeys.new creds.api_key,
                    creds.api_secret,
                    encryption_key || creds.encryption_key
      end

      def to_s
        "file #{filename}"
      end

      private

      def credentials_from_array(accounts, account_name = nil)
        account = if account_name
                    accounts.find { |a| a.name == account_name }
                  elsif accounts.size == 1
                    accounts.first
                  else
                    accounts.find(&:default_account)
                  end

        unless account
          raise DnsMadeEasy::APIKeyAndSecretMissingError,
                (account ? "account #{account} was not found" : 'Default account does not exist')
        end

        unless account.credentials
          raise DnsMadeEasy::InvalidCredentialsFormatError,
                'Expected an account entry to have the "credentials" key'
        end

        account.credentials
      end

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
        Hashie::Mash.new(YAML.safe_load(contents))
      end
    end
  end
end
