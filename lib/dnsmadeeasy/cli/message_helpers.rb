# frozen_string_literal: true

require 'tty-box'

module DnsMadeEasy
  module CLI
    # Convenience helpers for colorful boxed CLI status messages.
    module MessageHelpers
      BOX_OPTIONS = {
        border: { type: :thick },
        width: 85
      }.freeze

      class << self
        attr_accessor :stdout,
                      :stderr

        def info(message)
          print_to(stdout, TTY::Box.info(message, **BOX_OPTIONS))
        end

        def warn(message)
          print_to(stderr, TTY::Box.warn(message, **BOX_OPTIONS))
        end

        def error(message)
          print_to(stderr, TTY::Box.error(message, **BOX_OPTIONS))
        end

        def success(message)
          print_to(stdout, TTY::Box.success(message, **BOX_OPTIONS))
        end

        private

        def print_to(output, box)
          output.puts(box)
          box
        end
      end

      self.stdout = $stdout
      self.stderr = $stderr
    end
  end
end
