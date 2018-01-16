require 'spec_helper'
require 'yaml'
require 'hashie/mash'

module DnsMadeEasy
  RSpec.describe Credentials do

    let(:key) { '12345678-a8f8-4466-ffff-2324aaaa9098' }
    let(:secret) { '43009899-abcc-ffcc-eeee-09f809808098' }
    let(:encryption_key) { File.read('spec/fixtures/sym.key').chomp }

    context '.create' do
      subject(:api_keys) { ::DnsMadeEasy::Credentials.create(key, secret, encryption_key) }
      its(:api_key) { should eq key }
      its(:api_secret) { should eq secret }
    end

    context '.keys_from_file' do
      context 'simple file' do
        let(:file) { 'spec/fixtures/credentials.yml' }
        subject { described_class.keys_from_file(file: file) }

        it { is_expected.to be_kind_of ::DnsMadeEasy::Credentials::ApiKeys }
        it { is_expected.to_not be_nil }

        its(:api_key) { should eq '12345678-a8f8-4466-ffff-2324aaaa9098' }
        its(:api_secret) { should eq '43009899-abcc-ffcc-eeee-09f809808098' }
      end

      context 'multi-account file' do
        let(:file) { 'spec/fixtures/credentials-multi-account.yml' }
        subject { described_class.keys_from_file(file: file, account: 'production') }

        it { is_expected.to be_kind_of ::DnsMadeEasy::Credentials::ApiKeys }
        it { is_expected.to_not be_nil }

        its(:api_key) { should eq 'fcf80098-f2db-4a54-83f7-bcc990890980' }
        its(:api_secret) { should eq 'd09df9f9-b08d-481d-b5f5-40afafaaf9fc' }
      end
    end

    context '.default_credentials_paths' do
      subject { described_class.default_credentials_path }
      it { should eq File.expand_path('~/.dnsmadeeasy/credentials.yml') }
    end
  end
end

