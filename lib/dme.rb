# frozen_string_literal: true

require 'dnsmadeeasy'

module DME
  class << self
    def [](key, secret)
      ::DnsMadeEasy::Api::Client.new(key, secret)
    end

    # rubocop:todo Style/MissingRespondToMissing
    # rubocop:todo Style/MethodMissingSuper
    def method_missing(method, *args, &block)
      DnsMadeEasy.send(method, *args, &block)
    rescue NameError => e
      puts "Error: #{e.message}"
    end
    # rubocop:enable Style/MethodMissingSuper
    # rubocop:enable Style/MissingRespondToMissing
  end
end
