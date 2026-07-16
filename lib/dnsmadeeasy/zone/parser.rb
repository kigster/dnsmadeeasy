# frozen_string_literal: true

require 'dns/zonefile'
require 'dry/monads'
require 'dnsmadeeasy/zone/file'
require 'dnsmadeeasy/zone/record'
require 'dnsmadeeasy/zone/record_set'

module DnsMadeEasy
  module Zone
    # Parses standard zone-file text into provider-neutral records.
    class Parser
      include Dry::Monads[:result]

      SUPPORTED_RECORD_CLASSES = {
        'DNS::Zonefile::A' => 'A',
        'DNS::Zonefile::AAAA' => 'AAAA',
        'DNS::Zonefile::CNAME' => 'CNAME',
        'DNS::Zonefile::MX' => 'MX',
        'DNS::Zonefile::NS' => 'NS',
        'DNS::Zonefile::PTR' => 'PTR',
        'DNS::Zonefile::SPF' => 'SPF',
        'DNS::Zonefile::SRV' => 'SRV',
        'DNS::Zonefile::TXT' => 'TXT'
      }.freeze

      def initialize(zone_text)
        @zone_text = zone_text
      end

      def call
        zone = DNS::Zonefile.load(parseable_zone_text)
        records, errors = build_records(zone)
        return Failure(errors) if errors.any?

        Success(File.new(origin: zone_origin(zone), ttl: zone_ttl(zone), record_set: RecordSet.new(records: records)))
      rescue DNS::Zonefile::ParsingError, DNS::Zonefile::UnknownRecordType, Dry::Struct::Error => e
        Failure([e.message])
      end

      private

      attr_reader :zone_text

      def parseable_zone_text
        return zone_text if zone_text.match?(/\bSOA\b/)

        zone_lines = zone_text.lines
        insertion_index = zone_lines.index { |line| !line.strip.start_with?('$') && !line.strip.empty? } || zone_lines.length
        zone_lines.insert(insertion_index, synthetic_soa_line)
        zone_lines.join
      end

      def synthetic_soa_line
        "@ IN SOA ns.#{origin_from_text} hostmaster.#{origin_from_text} ( 1 1d 1d 4W #{ttl_from_text} )\n"
      end

      def origin_from_text
        zone_text[/^\$ORIGIN\s+(\S+)/, 1] || 'example.invalid.'
      end

      def ttl_from_text
        zone_text[/^\$TTL\s+(\d+)/, 1] || 300
      end

      def build_records(zone)
        origin = zone_origin(zone)
        zone.records.each_with_object([[], []]) do |provider_record, (records, errors)|
          next if provider_record.is_a?(DNS::Zonefile::SOA)

          record_type = SUPPORTED_RECORD_CLASSES[provider_record.class.name]
          if record_type
            records << build_record(provider_record, record_type, origin)
          else
            errors << "Unsupported DNS record type: #{provider_record.class.name.split('::').last}"
          end
        end
      end

      def zone_origin(zone)
        zone.soa&.origin || '.'
      end

      def zone_ttl(zone)
        zone.soa&.ttl || 300
      end

      def build_record(provider_record, record_type, origin)
        attributes = {
          owner: normalize_owner(provider_record.host, origin),
          type: record_type,
          value: record_value(provider_record, record_type, origin),
          ttl: provider_record.ttl
        }.merge(record_metadata(provider_record, record_type))

        Record.new(attributes)
      end

      def normalize_owner(host, origin)
        return '@' if host == origin

        host.delete_suffix(".#{origin}").delete_suffix('.')
      end

      def record_value(provider_record, record_type, origin)
        case record_type
        when 'A', 'AAAA'
          provider_record.address
        when 'CNAME', 'MX', 'NS', 'PTR', 'SRV'
          normalize_target(provider_record.domainname, origin)
        when 'SPF', 'TXT'
          normalize_text_value(provider_record.data)
        end
      end

      def normalize_target(target, origin)
        return '@' if target == origin

        target
      end

      def normalize_text_value(value)
        value.delete_prefix('"').delete_suffix('"')
      end

      def record_metadata(provider_record, record_type)
        case record_type
        when 'MX'
          { priority: provider_record.priority }
        when 'SRV'
          { priority: provider_record.priority, weight: provider_record.weight, port: provider_record.port }
        else
          {}
        end
      end
    end
  end
end
