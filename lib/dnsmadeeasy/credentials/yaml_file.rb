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
                  account = if account
                              mash.accounts.find { |a| a.name == account.to_s }
                            elsif
                              # rubocop:todo Layout/ConditionPosition
                              mash.accounts.size == 1
                              # rubocop:enable Layout/ConditionPosition
                              mash.accounts.first
                            else
                              mash.accounts.find(&:default_account)
                            end

                  unless account
                    raise DnsMadeEasy::APIKeyAndSecretMissingError,
                          (account ? "account #{account} was not found" : 'default account does not exist')
                  end

                  unless account.credentials
                    raise DnsMadeEasy::InvalidCredentialsFormatError,
                          'Expected account entry to have "credentials" key'
                  end

                  account.credentials

                elsif mash.credentials
                  mash.credentials

                else
                  raise DnsMadeEasy::InvalidCredentialsFormatError,
                        'expected either "accounts" or "credentials" as the top-level key'
                end

        # rubocop:todo Style/MultilineTernaryOperator
        creds ? ApiKeys.new(creds.api_key,
                            creds.api_secret,
                            encryption_key || creds.encryption_key) : nil
        # rubocop:enable Style/MultilineTernaryOperator
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
        Hashie::Mash.new(YAML.safe_load(contents))
      end
    end
  end
end
