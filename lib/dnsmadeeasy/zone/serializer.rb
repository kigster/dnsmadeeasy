# frozen_string_literal: true

require 'dnsmadeeasy/zone/file'

module DnsMadeEasy
  module Zone
    # Emits deterministic, normalized zone-file text.
    class Serializer
      def initialize(zone_file, omit_apex_ns: true)
        @zone_file = zone_file
        @omit_apex_ns = omit_apex_ns
      end

      def to_s
        lines = [
          "$ORIGIN #{zone_file.origin}",
          "$TTL #{zone_file.ttl}",
          ''
        ]
        lines.concat(serialized_records)
        "#{lines.join("\n")}\n"
      end

      private

      attr_reader :zone_file,
                  :omit_apex_ns

      def serialized_records
        grouped_records.flat_map.with_index do |records, index|
          lines = records.map { |record| serialize_record(record) }
          index.zero? ? lines : [''] + lines
        end
      end

      def grouped_records
        serializable_records.chunk { |record| record_group(record) }.map(&:last)
      end

      def serializable_records
        zone_file.records
                 .reject { |record| omit_apex_ns && record.owner == '@' && record.type == 'NS' }
                 .sort_by { |record| serializer_sort_key(record) }
      end

      def record_group(record)
        case record.type
        when 'MX'
          :mail
        when 'TXT', 'SPF'
          :text
        else
          :address
        end
      end

      def serializer_sort_key(record)
        [
          serializer_type_group(record),
          normalized_owner(record.owner),
          record.type,
          record.priority || -1,
          record.value,
          record.ttl
        ]
      end

      def serializer_type_group(record)
        case record.type
        when 'A', 'AAAA', 'CNAME', 'ANAME', 'NS', 'PTR'
          0
        when 'MX', 'SRV'
          1
        when 'TXT', 'SPF'
          2
        else
          3
        end
      end

      def normalized_owner(owner)
        owner == '@' ? '' : owner
      end

      def serialize_record(record)
        [record.owner.ljust(8), ttl_token(record), 'IN', record.type.ljust(7), record_payload(record)].compact.join(' ')
      end

      # A single $TTL cannot represent a real zone, so records that deviate
      # from the zone default carry an explicit TTL.
      def ttl_token(record)
        record.ttl == zone_file.ttl ? nil : record.ttl.to_s
      end

      def record_payload(record)
        case record.type
        when 'MX'
          "#{record.priority} #{record.value}"
        when 'SRV'
          "#{record.priority} #{record.weight} #{record.port} #{record.value}"
        when 'TXT', 'SPF'
          quote_text(record.value)
        else
          record.value
        end
      end

      def quote_text(value)
        return value if value.start_with?('"') && value.end_with?('"')

        %("#{value}")
      end
    end
  end
end
