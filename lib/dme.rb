# frozen_string_literal: true

require 'dnsmadeeasy'

module DME
  class << self
    def [](key, secret)
      ::DnsMadeEasy::Api::Client.new(key, secret)
    end

    def method_missing(method, ...)
      DnsMadeEasy.send(method, ...)
    rescue NameError => e
      puts "Error: #{e.message}"
    end

    def respond_to_missing?(method, include_private = false)
      DnsMadeEasy.respond_to?(method, include_private) || super
    end
  end
end
