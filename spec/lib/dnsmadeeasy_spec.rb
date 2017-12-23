require 'spec_helper'

module DnsMadeEasy
  RSpec.describe DnsMadeEasy do
    let(:spec_credentials_file) { 'spec/fixtures/credentials.yml' }

    before do
      DnsMadeEasy.configure do |config|
        config.api_key    = api_key
        config.api_secret = api_secret
      end
      DnsMadeEasy.instance_variable_set(:@client, nil)
      DnsMadeEasy.instance_variable_set(:@sandbox_client, nil)
    end

    let(:api_key) { '12345678-a8f8-4466-ffff-2324aaaa9098' }
    let(:api_secret) { '43009899-abcc-ffcc-eeee-09f809808098' }

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

    context 'file credentials' do
      let(:file) { spec_credentials_file }
      let(:key) { '12345678-a8f8-4466-ffff-2324aaaa9098' }
      let(:secret) { '43009899-abcc-ffcc-eeee-09f809808098' }

      before { DnsMadeEasy.configure_from_file(file) }

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

    context 'unknown method' do
      let(:bad_method) { :i_am_a_bad_method }
      it 'should raise NameError' do
        expect { DnsMadeEasy.send(bad_method) }.to raise_error(NameError)
      end
    end
  end
end
