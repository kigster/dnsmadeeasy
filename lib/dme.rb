# frozen_string_literal: true

require 'dnsmadeeasy'

module DME
  class << self
    def [](key, secret)
      ::DnsMadeEasy::Api::Client.new(key, secret)
    end
    def method_missing(method, *args, &block)
      DnsMadeEasy.send(method, *args, &block)
    rescue NameError => e
      puts "Error: #{e.message}"
    end
  end
end
