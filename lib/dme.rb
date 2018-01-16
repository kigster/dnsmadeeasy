require 'dnsmadeeasy'

module DME
  class << self
    def [](key, secret)
      ::DnsMadeEasy::Api::Client.new(key, secret)
    end

    def method_missing(method, *args, &block)
      begin
        DnsMadeEasy.send(method, *args, &block)
      rescue NameError => e
        puts "Error: #{e.message}"
      end
    end
  end
end
