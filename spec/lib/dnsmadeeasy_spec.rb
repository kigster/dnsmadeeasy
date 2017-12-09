require 'spec_helper'

module DnsMadeEasy
  RSpec.describe DnsMadeEasy do
    before do
      DnsMadeEasy.configure do |config|
        config.api_key    = api_key
        config.api_secret = api_secret
      end
      DnsMadeEasy.instance_variable_set(:@client, nil)
      DnsMadeEasy.instance_variable_set(:@sandbox_client, nil)
    end

    let(:api_key) { 'soooo secret' }
    let(:api_secret) { 'soooo secret' }


    context 'real client' do
      subject(:client) { described_class.client }
      its(:base_uri) { should eq(API_BASE_URL_PRODUCTION) }
      context 'without the key and secret' do
        let(:api_key) { nil }
        let(:api_secret) { nil }

        it 'should raise ArgumentError' do
          expect { client }.to raise_error(APIKeyAndSecretMissingError)
        end

      end

      context 'with key and secret' do
        it { is_expected.to be_kind_of(DnsMadeEasy::Api::Client) }
        it { is_expected.to respond_to(:get_id_by_domain) }
      end
    end

    context 'sandbox client' do
      subject(:client) { described_class.sandbox_client }
      its(:base_uri) { should eq(API_BASE_URL_SANDBOX) }
    end
  end
end
