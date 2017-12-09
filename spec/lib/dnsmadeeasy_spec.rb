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
        before do
          expect(DnsMadeEasy).to receive(:default!)
        end

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

    context 'file credentials' do
      let(:file) { 'spec/fixtures/credentials.yml' }
      let(:key) { '2062259f-f666b17-b1fa3b48-042ad4030' }
      let(:secret) { '2265bc3-e31ead-95b286312e-c215b6a0' }

      before { DnsMadeEasy.credentials = file }

      it 'should now correct set api_key' do
        expect(DnsMadeEasy.api_key).to eq key
        expect(DnsMadeEasy.api_secret).to eq secret
      end

      context 'method delegation' do
        it 'should call through to the client' do
          expect(DnsMadeEasy.base_uri).to eq(DnsMadeEasy::API_BASE_URL_PRODUCTION)
        end

      end
    end

  end
end
