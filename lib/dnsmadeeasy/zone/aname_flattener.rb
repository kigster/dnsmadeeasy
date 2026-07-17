# frozen_string_literal: true

require 'dry/monads'
require 'resolv'
require 'dnsmadeeasy/zone/record'

module DnsMadeEasy
  module Zone
    # Flattens ANAME records into resolved A records for RFC-portable
    # exports. Resolution is a point-in-time snapshot, so every conversion
    # is reported as a notice.
    class AnameFlattener
      include Dry::Monads[:result]

      def initialize(records, resolver: nil)
        @records = records
        @resolver = resolver || default_resolver
      end

      def call
        flattened = []
        notices = []

        records.each do |record|
          if record.type == 'ANAME'
            addresses = resolve(record)
            return Failure(["Unable to resolve ANAME target #{record.value} for --strict-rfc export"]) if addresses.empty?

            addresses.each { |address| flattened << record.new(type: 'A', value: address) }
            notices << flatten_notice(record, addresses)
          else
            flattened << record
          end
        end

        Success([flattened, notices])
      end

      private

      attr_reader :records,
                  :resolver

      def resolve(record)
        resolver.call(record.value)
      rescue Resolv::ResolvError
        []
      end

      def flatten_notice(record, addresses)
        "Flattened ANAME #{record.owner} -> #{record.value} into A #{addresses.join(', ')} (point-in-time snapshot)"
      end

      def default_resolver
        lambda do |target|
          Resolv::DNS.open do |dns|
            dns.getresources(target, Resolv::DNS::Resource::IN::A).map { |resource| resource.address.to_s }
          end
        end
      end
    end
  end
end
