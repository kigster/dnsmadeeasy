require 'spec_helper'
require 'yaml'
require 'hashie/mash'
require 'hashie/extensions/symbolize_keys'

module DnsMadeEasy
  module Credentials

    RSpec.describe YamlFile do
      subject(:yaml_file) { described_class.new(filename: file) }
      let(:hash) { Hashie::Mash.new(
        Hashie::Extensions::SymbolizeKeys.symbolize_keys(
          ::YAML.load(
            ::File.read(file))))
      }

      let(:key) { '12345678-a8f8-4466-ffff-2324aaaa9098' }
      let(:secret) { '43009899-abcc-ffcc-eeee-09f809808098' }
      let(:encryption_key) { nil }

      context 'single account' do
        let(:file) { 'spec/fixtures/credentials.yml' }

        context 'fixture file' do
          subject { hash.credentials }
          its(:api_key) { should eq key }
          its(:api_secret) { should eq secret }
        end

        context 'single account account' do
          let(:api_keys) { ApiKeys.new(key, secret, encryption_key) }
          its(:keys) { should eq api_keys }
        end

      end

      context 'multi-account' do
        let(:file) { 'spec/fixtures/credentials-multi-account.yml' }
        let(:accounts) { hash.accounts }
        let(:encryption_key) { nil }

        context 'validate the fixture hash' do
          subject { accounts }
          it { is_expected.to_not be_nil }
          its(:size) { should eq 3 }
          its(:first) { should include(:name) }
        end

        subject(:keys) { yaml_file.keys(account_name: account_name) }

        let(:expected_keys) { ApiKeys.new(creds.api_key, creds.api_secret, encryption_key) }

        context 'fetch a sub-account without encryption' do
          let(:creds) { accounts.last.credentials }
          let(:account_name) { 'staging' }

          its(:api_key) { should eq key }
          its(:api_secret) { should eq secret }
          it { is_expected.to be_valid }
          it { is_expected.to eql(expected_keys) }
        end

        context 'fetch a sub-account with encryption' do
          let(:creds) { accounts.first.credentials }
          let(:account_name) { 'production' }
          let(:encryption_key) { File.read('spec/fixtures/sym.key').chomp }

          its(:api_key) { should eq 'fcf80098-f2db-4a54-83f7-bcc990890980' }
          its(:api_secret) { should eq 'd09df9f9-b08d-481d-b5f5-40afafaaf9fc' }
          its(:encryption_key) { should eq(encryption_key) }

          it { is_expected.to be_valid }
          it { is_expected.to eql(expected_keys) }

          context 'when encryption key is not in the file' do
            context 'and we dont pass it in' do
              subject(:keys) { yaml_file.keys(account_name: 'preview') }
              it 'should raise error' do
                expect { keys }.to raise_error(DnsMadeEasy::InvalidCredentialKeys)
              end
            end

            context 'and we do pass it in' do
              subject(:keys) { yaml_file.keys(account_name:   'preview',
                                              encryption_key: encryption_key) }
              context 'as a pathname' do
                let(:encryption_key) { 'spec/fixtures/sym.key' }
                it { is_expected.to eql(expected_keys) }
              end

              context 'as a key itself' do
                let(:encryption_key) { File.read('spec/fixtures/sym.key').chomp }
                it { is_expected.to eql(expected_keys) }
              end
            end
          end
        end
      end
    end
  end
end
