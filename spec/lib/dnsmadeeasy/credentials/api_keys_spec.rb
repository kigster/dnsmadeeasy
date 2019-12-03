# frozen_string_literal: true

require 'spec_helper'
require 'yaml'
require 'hashie/mash'

module DnsMadeEasy
  module Credentials
    RSpec.describe ApiKeys do # rubocop:todo Metrics/BlockLength
      let(:key) { '12345678-a8f8-4466-ffff-2324aaaa9098' }
      let(:real_key) { '12345678-a8f8-4466-ffff-2324aaaa9098' }

      let(:secret) { 'd09df9f9-b08d-481d-b5f5-40afafaaf9fc' }
      let(:real_secret) { 'd09df9f9-b08d-481d-b5f5-40afafaaf9fc' }

      let(:encryption_key) { nil }

      subject(:api_keys) { described_class.new(key, secret, encryption_key) }

      context 'valid data' do # rubocop:todo Metrics/BlockLength
        context 'non-encrypted ApiKeys' do
          its(:api_key) { should eq real_key }
          its(:api_secret) { should eq real_secret }
          its(:to_s) { should match Digest::SHA256.hexdigest(real_key) }
          its(:to_s) { should match Digest::SHA256.hexdigest(real_secret) }
          its(:to_s) { should match /^<DnsMadeEasy::Credentials::ApiKey/ }
        end

        context 'encrypted key' do
          let(:key) { 'BAhTOh1TeW06OkRhdGE6OldyYXBwZXJTdHJ1Y3QLOhNlbmNyeXB0ZWRfZGF0YSJVCLXPOvZ11uKhIpdtirf1epE8SkIsAhhFJCe82PdWyCgj-egHpMS8HT99KOb77bAaR92oZyw9P_IJT4cSm1eMMF-lMe3s3R8zcgyszhQekl86B2l2IhW-7YdcTPHDknka75PEJtgvOhBjaXBoZXJfbmFtZSIQQUVTLTI1Ni1DQkM6CXNhbHQwOgx2ZXJzaW9uaQY6DWNvbXByZXNzVA==' }
          let(:secret) { 'BAhTOh1TeW06OkRhdGE6OldyYXBwZXJTdHJ1Y3QLOhNlbmNyeXB0ZWRfZGF0YSJVHE1D3mpTsUseEdm3NWox7xdeQExobVx3-dHnEJoK9XYXawoPvtgroxOhsaYxZtxz_ZeHtSDZwu0eyDVyZ-XDo-vxalo9cQ2FOm05hVQaebo6B2l2IhVosiRfW5FnRK4BxfwPytLcOhBjaXBoZXJfbmFtZSIQQUVTLTI1Ni1DQkM6CXNhbHQwOgx2ZXJzaW9uaQY6DWNvbXByZXNzVA==' }
          it 'should raise error without encryption key' do
            expect { subject }.to raise_error(InvalidCredentialKeys)
          end
          context 'with completely invalid encryption key' do
            let(:encryption_key) { 'brooohahaha' }
            it 'should raise error without encryption key' do
              expect { subject }.to raise_error(DnsMadeEasy::InvalidCredentialKeys)
            end
          end
          context 'with a valid but wrong encryption key' do
            let(:encryption_key) { 'TLcs17hNPuGkoIFG--hgM7hMJ74OPwzrqUoFSVqwBBg=' }
            it 'should raise error without encryption key' do
              expect { subject }.to raise_error(OpenSSL::Cipher::CipherError)
            end
          end
          context 'with a valid but proper key' do
            let(:encryption_key) { File.read('spec/fixtures/sym.key').chomp }
            its(:api_key) { should eq real_key }
            its(:api_secret) { should eq real_secret }
          end
        end
      end

      context 'invalid data' do
        let(:key) { '12345678-a8f8-4466-ffff-2324aaaa9098-03920948230984' }
        it 'should raise error' do
          expect { subject }.to raise_error(InvalidCredentialKeys)
        end
      end
    end
  end
end
