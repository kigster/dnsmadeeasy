# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DnsMadeEasy::Api::Client do
  let(:api_domain) { DnsMadeEasy::API_BASE_URL_PRODUCTION }
  let(:user_domain)  { 'something.somedomain.boo' }
  let(:api_key) { 'soooo secret' }
  let(:secret_key) { 'soooo secret' }
  let(:request_headers) do
    { 'Accept' => 'application/json',
      'X-Dnsme-Apikey' => 'soooo secret',
      'X-Dnsme-Hmac' => 'ff6e87e78ff909573362c9a38df13ccc5fa01846',
      'X-Dnsme-Requestdate' => 'Wed, 21 May 2014 18:08:37 GMT' }
  end

  subject(:client) { described_class.new(api_key, secret_key) }

  context 'base_uri' do
    its(:base_uri) { should eq api_domain }
    context 'on_sandbox' do
      it 'should temporarily set it to sandbox URL' do
        client.on_sandbox do
          expect(client.base_uri).to eq DnsMadeEasy::API_BASE_URL_SANDBOX
        end
        expect(client.base_uri).to eq api_domain
      end
    end
  end

  before do
    allow(Time).to receive(:now).and_return(Time.parse('Wed, 21 May 2014 18:08:37 GMT'))
  end

  describe '#get_id_by_domain' do
    let(:response) do
      '{"name":"something.somedomain.boo","id":1130967}'
    end

    it 'returns the id of the domain' do
      stub_request(:get, api_domain + '/dns/managed/id/something.somedomain.boo')
        .with(headers: request_headers)
        .to_return(status: 200, body: response, headers: {})

      expect(subject.get_id_by_domain(user_domain)).to eq(1_130_967)
    end
  end

  describe '#domains' do
    let(:response) { '{}' }

    it 'returns all the domains' do
      stub_request(:get, api_domain + '/dns/managed/')
        .with(headers: request_headers)
        .to_return(status: 200, body: response, headers: {})

      expect(subject.domains).to eq({})
    end
  end

  describe '#domain' do
    let(:response) { '{}' }

    before do
      expect(subject).to receive(:get_id_by_domain).with(user_domain).and_return(123)
    end

    it 'returns the domain given a domain name' do
      stub_request(:get, api_domain + '/dns/managed/123')
        .with(headers: request_headers)
        .to_return(status: 200, body: response, headers: {})

      expect(subject.domain(user_domain)).to eq({})
    end
  end

  describe '#delete_domain' do
    let(:response) { '{}' }

    before do
      expect(subject).to receive(:get_id_by_domain).with(user_domain).and_return(123)
    end

    it 'deletes the domain' do
      stub_request(:delete, api_domain + '/dns/managed/123')
        .with(headers: request_headers)
        .to_return(status: 200, body: response, headers: {})

      expect(subject.delete_domain(user_domain)).to eq({})
    end
  end

  describe '#create_domains' do
    let(:response) { '{}' }

    it 'creates the domains' do
      stub_request(:post, api_domain + '/dns/managed/')
        .with(headers: request_headers, body: '{"names":["' + user_domain + '"]}')
        .to_return(status: 200, body: response, headers: {})

      expect(subject.create_domains([user_domain])).to eq({})
    end
  end

  describe '#create_domain' do
    it 'calls create_domains with the one domain' do
      expect(subject).to receive(:create_domains).with([user_domain])
      subject.create_domain(user_domain)
    end
  end

  describe '#records_for' do
    let(:response) { '{}' }

    before do
      expect(subject).to receive(:get_id_by_domain).with(user_domain).twice.and_return(123)
    end

    it 'returns all records for a given domain' do
      stub_request(:get, api_domain + '/dns/managed/123/records')
        .with(headers: request_headers)
        .to_return(status: 200, body: response, headers: {})

      expect(subject.records_for(user_domain)).to eq({})
      expect(subject.all(user_domain)).to eq({})
    end
  end

  describe 'multiple return values' do
    let(:records_for_response) do
      {
        'data' => [
          { 'name' => 'demo', 'type' => 'A', 'id' => 123 },
          { 'name' => 'demo', 'type' => 'A', 'id' => 143 }
        ]
      }
    end

    before do
      expect(subject).to receive(:records_for).with(user_domain).and_return(records_for_response)
    end

    context '#find_first' do
      it 'finds the first record that matches name and type' do
        expect(subject.find_first(user_domain, 'demo', 'A')).to eq('name' => 'demo', 'type' => 'A', 'id' => 123)
      end
    end

    context '#find_all' do
      it 'finds the first record that matches name and type' do
        expect(subject.find_all(user_domain, 'demo', 'A')).to eq(records_for_response['data'])
      end
    end
  end

  describe '#find_record_id' do
    let(:records_for_response) do
      {
        'data' => [
          { 'name' => 'demo', 'type' => 'A', 'id' => 123 },
          { 'name' => 'demo', 'type' => 'A', 'id' => 143 }
        ]
      }
    end

    before do
      expect(subject).to receive(:records_for).with(user_domain).and_return(records_for_response)
    end

    it 'finds the specified record given a name and a type' do
      expect(subject.find_record_ids(user_domain, 'demo', 'A')).to eq([123, 143])
    end
  end

  describe '#delete_records' do
    let(:response) { '{}' }
    let(:domain) { user_domain }
    let(:domain_id) { 123 }

    context 'with an array of record ids' do
      let(:ids) { [147, 159] }

      before do
        expect(subject).to receive(:get_id_by_domain).with(domain).and_return(domain_id)

        stub_request(:delete, "https://api.dnsmadeeasy.com/V2.0/dns/managed/#{domain_id}/records?ids=#{ids.join(',')}")
          .with(headers: request_headers)
          .to_return(status: 200, body: response, headers: {})
      end

      it 'deletes a list of records from a given domain' do
        expect(subject.delete_records(user_domain, ids)).to eq({})
      end
    end

    context 'with an empty array' do
      it 'returns early without deleting anything' do
        expect(subject.delete_records(user_domain, [])).to eq(nil)
      end
    end
  end

  describe '#delete_all_records' do
    let(:response) { '{}' }
    let(:domain) { user_domain }
    let(:domain_id) { 123 }

    before do
      expect(subject).to receive(:get_id_by_domain).with(domain).and_return(domain_id)

      stub_request(:delete, "https://api.dnsmadeeasy.com/V2.0/dns/managed/#{domain_id}/records")
        .with(headers: request_headers)
        .to_return(status: 200, body: response, headers: {})
    end

    it 'deletes all records from the domain' do
      expect(subject.delete_all_records(user_domain)).to eq({})
    end
  end

  describe '#delete_record' do
    let(:response) { '{}' }

    before do
      expect(subject).to receive(:get_id_by_domain).with(user_domain).and_return(123)
    end

    it 'deletes a record' do
      stub_request(:delete, api_domain + '/dns/managed/123/records/42/')
        .with(headers: request_headers)
        .to_return(status: 200, body: response, headers: {})

      expect(subject.delete_record(user_domain, 42)).to eq({})
    end
  end

  describe '#create_record' do
    let(:response) { '{}' }

    before do
      expect(subject).to receive(:get_id_by_domain).with(user_domain).and_return(123)
    end

    let(:domain_name) { user_domain }
    let(:name) { 'test' }

    it 'creates a record' do
      stub_request(:post, api_domain + '/dns/managed/123/records/')
        .with(headers: request_headers, body: { 'name' => 'test', 'type' => 'A', 'value' => '192.168.1.1', 'ttl' => 3600, 'gtdLocation' => 'DEFAULT' }.to_json)
        .to_return(status: 200, body: response, headers: {})

      expect(subject.create_record(domain_name, 'test', 'A', '192.168.1.1')).to eq({})
    end
  end

  %w[a aaaa ptr txt cname ns spf].each do |record_type|
    method_name = "create_#{record_type}_record"
    describe "##{method_name}" do
      upper_record_type = record_type.upcase

      it "calls through to create record with \"#{upper_record_type}\"" do
        expect(subject).to receive(:create_record).with(user_domain,
                                                        'smellyface',
                                                        upper_record_type,
                                                        '192.168.1.1', {}).and_return({})
        expect(subject.send(method_name, user_domain,
                            'smellyface', '192.168.1.1')).to eq({})
      end
    end
  end

  describe '#create_mx_record' do
    it 'creates an mx record' do
      expect(subject).to receive(:create_record).with(user_domain, 'mail', 'MX', '192.168.1.1', 'mxLevel' => 50).and_return({})
      expect(subject.create_mx_record(user_domain, 'mail', 50, '192.168.1.1')).to eq({})
    end
  end

  describe '#create_srv_record' do
    let(:weight) { '50' }
    let(:priority) { '42' }
    let(:port) { '4040' }

    it 'creates an srv record' do
      expect(subject).to receive(:create_record).with(user_domain,
                                                      'serv',
                                                      'SRV',
                                                      '192.168.1.1',
                                                      'priority' => priority,
                                                      'weight' => weight,
                                                      'port' => port).and_return({})

      expect(subject.create_srv_record(user_domain, 'serv',
                                       priority,
                                       weight,
                                       port,
                                       '192.168.1.1')).to eq({})
    end
  end

  describe '#create_httpred_record' do
    let(:description) { 'hunky dory redirect description' }
    let(:keywords) { 'omg,keywords,redirect' }
    let(:redirect_type) { 'STANDARD - 302' }
    let(:title) { 'wat' }

    it 'creates an srv record' do
      expect(subject).to receive(:create_record).with(user_domain,
                                                      'redirect', 'HTTPRED', '192.168.1.1',
                                                      'redirectType' => redirect_type,
                                                      'description' => description,
                                                      'keywords' => keywords,
                                                      'title' => title).and_return({})

      expect(subject.create_httpred_record(user_domain,
                                           'redirect',
                                           '192.168.1.1',
                                           redirect_type,
                                           description,
                                           keywords,
                                           title)).to eq({})
    end
  end

  describe '#update_record' do
    let(:response) { '{}' }

    before do
      expect(subject).to receive(:get_id_by_domain).with(user_domain).and_return(123)
    end

    it 'updates a record' do
      body = '{"name":"mail","type":"A","value":"1.1.1.1","ttl":3600,"gtdLocation":"DEFAULT","id":21}'

      stub_request(:put, api_domain + '/dns/managed/123/records/21/')
        .with(headers: request_headers, body: body)
        .to_return(status: 200, body: response, headers: {})

      expect(subject.update_record(user_domain, 21, 'mail', 'A', '1.1.1.1', {})).to eq({})
    end
  end

  describe '#update_records' do
    let(:response) { '{}' }

    before do
      expect(subject).to receive(:get_id_by_domain).with(user_domain).and_return(123)
    end

    it 'updates a record' do
      records = [
        {
          'id' => 21,
          'name' => 'mail',
          'type' => 'A',
          'value' => '1.1.1.1',
          'gtdLocation' => 'DEFAULT',
          'ttl' => 300
        },
        {
          'id' => 22,
          'name' => 'post',
          'type' => 'A',
          'value' => '1.1.1.2',
          'gtdLocation' => 'DEFAULT',
          'ttl' => 300
        }
      ]

      body = '[{"id":21,"name":"mail","type":"A","value":"1.1.1.1","gtdLocation":"DEFAULT","ttl":3600},{"id":22,"name":"post","type":"A","value":"1.1.1.2","gtdLocation":"DEFAULT","ttl":3600}]'

      stub_request(:put, api_domain + '/dns/managed/123/records/updateMulti/')
        .with(headers: request_headers, body: body)
        .to_return(status: 200, body: response, headers: {})

      expect(subject.update_records(user_domain, records, 'ttl' => 3600)).to eq({})
    end
  end

  describe '#secondary_domains' do
    let(:response) { '{}' }

    it 'returns all the domains' do
      stub_request(:get, api_domain + '/dns/secondary')
        .with(headers: request_headers)
        .to_return(status: 200, body: response, headers: {})

      expect(subject.secondary_domains).to eq({})
    end
  end

  describe '#secondary_domain' do
    let(:response) { '{}' }
    let(:domain_id) { 123 }

    it 'returns the domain' do
      stub_request(:get, api_domain + "/dns/secondary/#{domain_id}" )
        .with(headers: request_headers)
        .to_return(status: 200, body: response, headers: {})

      expect(subject.secondary_domain(domain_id)).to eq({})
    end
  end

  describe '#create_secondary_domains' do
    let(:response) { '{}' }
    let(:ip_set_id) { 123 }

    it 'creates the domains' do
      stub_request(:post, api_domain + '/dns/secondary')
        .with(headers: request_headers, body: { names: [user_domain], ipSetId: ip_set_id }.to_json)
        .to_return(status: 200, body: response, headers: {})

      expect(subject.create_secondary_domains([user_domain], ip_set_id)).to eq({})
    end
  end

  describe '#create_secondary_domain' do
    let(:ip_set_id) { 123 }

    it 'calls create_secondary_domains with one domain' do
      expect(subject).to receive(:create_secondary_domains).with([user_domain], ip_set_id)
      subject.create_secondary_domain(user_domain, ip_set_id)
    end
  end

  describe '#update_secondary_domains' do
    let(:response) { '{}' }
    let(:ip_set_id) { 123 }
    let(:domain_ids) { [1, 2, 3] }

    it 'updates domains' do
      stub_request(:put, api_domain + '/dns/secondary')
        .with(headers: request_headers, body: { ids: domain_ids, ipSetId: ip_set_id }.to_json)
        .to_return(status: 200, body: response, headers: {})

      expect(subject.update_secondary_domains(domain_ids, ip_set_id)).to eq({})
    end
  end

  describe '#get_id_by_secondary_domain' do
    let(:response) {
      {
        data: [
          {
            ipSetId: 11_341,
            name: user_domain,
            id: 123
          },
        ],
      }.to_json
    }

    before do
      expect(subject).to receive(:secondary_domains).and_return(JSON.parse(response))
    end

    it 'gets id of domain' do
      expect(subject.get_id_by_secondary_domain(user_domain)).to eq(123)
    end

    it 'raises if no domain is found' do
      expect {
        subject.get_id_by_secondary_domain('non-existing-domain')
      }.to raise_error(DnsMadeEasy::NoDomainError)
    end
  end

  describe '#delete_secondary_domain' do
    let(:response) { '{}' }

    before do
      expect(subject).to receive(:get_id_by_secondary_domain).with(user_domain).and_return(123)
    end

    it 'deletes the domain' do
      stub_request(:delete, api_domain + '/dns/secondary/123')
        .with(headers: request_headers)
        .to_return(status: 200, body: response, headers: {})

      expect(subject.delete_secondary_domain(user_domain)).to eq({})
    end
  end

  describe '#secondary_ip_sets' do
    let(:response) { '{}' }

    it 'returns all the ip_sets' do
      stub_request(:get, api_domain + '/dns/secondary/ipSet')
        .with(headers: request_headers)
        .to_return(status: 200, body: response, headers: {})

      expect(subject.secondary_ip_sets).to eq({})
    end
  end

  describe '#secondary_ip_set' do
    let(:response) { '{}' }
    let(:ip_set_id) { 123 }

    it 'returns ip_set' do
      stub_request(:get, api_domain + "/dns/secondary/ipSet/#{ip_set_id}" )
        .with(headers: request_headers)
        .to_return(status: 200, body: response, headers: {})

      expect(subject.secondary_ip_set(ip_set_id)).to eq({})
    end
  end

  describe '#create_secondary_ip_set' do
    let(:response) { '{}' }
    let(:ips) { %w[1.2.3.4 5.6.7.8] }
    let(:name) { 'ip-set-name' }

    it 'creates ip_set' do
      stub_request(:post, api_domain + "/dns/secondary/ipSet")
        .with(headers: request_headers, body: { name: name, ips: ips }.to_json)
        .to_return(status: 200, body: response, headers: {})

      expect(subject.create_secondary_ip_set(name, ips)).to eq({})
    end
  end

  describe '#update_secondary_ip_set' do
    let(:response) { '{}' }
    let(:ip_set_id) { 123 }
    let(:ips) { %w[1.2.3.4 5.6.7.8] }
    let(:name) { 'ip-set-name' }

    it 'updates ip_set' do
      stub_request(:put, api_domain + "/dns/secondary/ipSet/#{ip_set_id}")
        .with(headers: request_headers, body: { name: name, id: ip_set_id, ips: ips }.to_json)
        .to_return(status: 200, body: response, headers: {})

      expect(subject.update_secondary_ip_set(ip_set_id, name, ips)).to eq({})
    end
  end

  describe '#delete_secondary_ip_set' do
    let(:response) { '{}' }
    let(:ip_set_id) { 123 }

    it 'delete ip set' do
      stub_request(:delete, api_domain + "/dns/secondary/ipSet/#{ip_set_id}")
        .with(headers: request_headers)
        .to_return(status: 200, body: response, headers: {})

      expect(subject.delete_secondary_ip_set(ip_set_id)).to eq({})
    end
  end

  describe '#request' do
    before do
      stub_request(:get, api_domain + '/some_path')
        .with(headers: request_headers)
        .to_return(status: status, body: body, headers: {})
    end

    let(:response) do
      subject.send(:request, '/some_path') do |uri|
        Net::HTTP::Get.new(uri.path)
      end
    end

    context 'with a 2xx, empty-string response' do
      let(:status) { 200 }
      let(:body) { '' }

      it 'handles gracefully' do
        expect(response).to eq({})
      end
    end

    context 'with a non-2xx response' do
      let(:status) { 400 }
      let(:body) { "<xml> JSON.parse won't like this very much </xml>" }

      it 'raises a Net::HTTPServerException instead of a JSON::ParserError' do
        expect { response }.to raise_exception(Net::HTTPServerException)
      end
    end
  end

  context '#process_response' do
    let(:response) { double }
    let(:message) { '403 "Forbidden"' }

    context 'with a 403 response' do
      before do
        expect(response).to receive(:value).and_raise(::Net::HTTPServerException.new(message, response))
      end

      it 'raises a AuthenticationError' do
        expect { subject.send(:process_response!, response) }.to raise_exception(DnsMadeEasy::AuthenticationError)
      end
    end
  end

  describe '#request' do
    before do
      class FakeHeaders < Hash
        alias each_header each_pair
      end
    end

    let(:response) { FakeHeaders.new }

    before do
      response['x-dnsme-requestsremaining'] = 2345
      response['x-dnsme-requestlimit']      = 20_000
    end
    before { subject.send(:process_rate_limits, response) }

    context 'with a 2xx, empty-string response' do
      its(:request_limit) { is_expected.to eq(20_000) }
      its(:requests_remaining) { is_expected.to eq(2345) }
    end
  end

  describe '.public_operations' do
    subject { described_class.public_operations }
    it { is_expected.to include('create_record') }
    it { is_expected.to include('all') }
    it { is_expected.not_to include('api_key') }
    it { is_expected.not_to include('api_secret') }
    it { is_expected.not_to include('base_url=') }
    it { is_expected.not_to include('on_production') }
  end
end
