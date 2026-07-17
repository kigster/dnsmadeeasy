# frozen_string_literal: true

require 'dry/types'

module DnsMadeEasy
  # Shared dry-rb types used by value objects.
  module Types
    include Dry.Types()

    DNS_RECORD_TYPES = %w[A AAAA CNAME ANAME MX NS PTR SPF SRV TXT].freeze

    StrictString = Strict::String
    NonEmptyString = StrictString.constrained(min_size: 1)
    RecordType = StrictString.enum(*DNS_RECORD_TYPES)
    Ttl = Coercible::Integer.constrained(gteq: 0)
    OptionalInteger = Coercible::Integer.optional
    OptionalString = StrictString.optional
  end
end
