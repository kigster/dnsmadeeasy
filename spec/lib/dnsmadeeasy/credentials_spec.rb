require 'spec_helper'
require 'yaml'

module DnsMadeEasy
  RSpec.describe 'API Keys and Secrets' do

    let(:key) { '2062259f-f666b17-b1fa3b48-042ad4030' }
    let(:secret) { '2265bc3-e31ead-95b286312e-c215b6a0' }
    let(:file) { 'spec/fixtures/credentials.yml' }
    let(:hash) { ::YAML.load(::File.read(file)) }

    it 'api_key' do
      expect(hash['credentials']['api_key']).to eq key
    end

    it 'api_secret' do
      expect(hash['credentials']['api_secret']).to eq secret
    end

    context '#symbolize' do
      subject(:creds) { Credentials.new.merge!(hash)}

      before { creds.symbolize! }

      it 'should' do
        expect(subject[:credentials]).to_not be_nil
      end

      it 'should now have symbolized keys' do
        expect(creds[:credentials]).to_not be_nil
        expect(creds[:credentials]).to be_kind_of(Hash)
        expect(creds[:credentials][:api_key]).to eq key
        expect(creds[:credentials][:api_secret]).to eq secret
      end

      it 'should modify hash itself only with symbolize!' do
        expect(hash.keys.first).to eq 'credentials'
      end
    end


    context Credentials do
      subject(:cred) { Credentials.load(file) }

      its(:api_key) { should eq hash['credentials']['api_key'] }
      its(:api_secret) { should eq hash['credentials']['api_secret'] }

      context 'when reading from an invalid file' do
        let(:file) { '/tmp/903285r0we9oufijsdlkjewlasijhlewahfsdlaisj' }

        it 'should raise an exception' do
          expect { cred }.to raise_error(DnsMadeEasy::Credentials::CredentialsFileNotFound)
        end
      end
    end
  end


end
