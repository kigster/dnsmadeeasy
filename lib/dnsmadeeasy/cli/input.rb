# frozen_string_literal: true

module DnsMadeEasy
  module CLI
    # Shared input stream for commands that need confirmation.
    module Input
      class << self
        attr_accessor :stdin
      end

      self.stdin = $stdin
    end
  end
end
