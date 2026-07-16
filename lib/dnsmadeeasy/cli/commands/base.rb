# frozen_string_literal: true

require 'dry/cli'

module DnsMadeEasy
  module CLI
    module Commands
      # Base class for dry-cli commands.
      class Base < Dry::CLI::Command
        private

        def puts(*)
          @out.puts(*)
        end
      end
    end
  end
end
