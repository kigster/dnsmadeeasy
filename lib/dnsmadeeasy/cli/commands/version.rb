# frozen_string_literal: true

require 'dnsmadeeasy/version'
require 'dnsmadeeasy/cli/commands/base'

module DnsMadeEasy
  module CLI
    # Registered dry-cli command classes.
    module Commands
      # Prints the gem version.
      class Version < Base
        desc 'Print version'

        def call(*)
          puts DnsMadeEasy::VERSION
        end
      end

      register 'version', Version, aliases: %w[v -v --version]
    end
  end
end
