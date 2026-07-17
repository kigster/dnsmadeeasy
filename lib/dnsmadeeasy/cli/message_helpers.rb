# frozen_string_literal: true

require 'tty-box'

module DnsMadeEasy
  module CLI
    # Colorful boxed CLI status messages. All boxes print to stderr so that
    # stdout carries only command payload (zone files, plan output) and
    # stays safe to pipe or redirect.
    #
    # Include the module to call info/success/warning/error directly from a
    # command; boxes then print to the includer's @err stream when present.
    # The module-level methods (MessageHelpers.error etc.) remain available
    # for callers outside the command classes.
    module MessageHelpers
      BOX_OPTIONS = {
        border: { type: :thick },
        width: 85
      }.freeze

      class << self
        attr_accessor :stdout, :stderr

        def included(base)
          base.include(InstanceMethods)
        end

        def info(message)
          print_box(:info, message, stderr)
        end

        def warn(message)
          print_box(:warn, message, stderr)
        end

        def error(message)
          print_box(:error, message, stderr)
        end

        def success(message)
          print_box(:success, message, stderr)
        end

        def print_box(box_type, message, output)
          box = TTY::Box.public_send(box_type, message, **BOX_OPTIONS)
          output.puts(box)
          box
        end
      end

      # Boxed helpers for command classes. The warn box is exposed as
      # #warning because commands already use Kernel-style plain #warn.
      module InstanceMethods
        def info(message)
          MessageHelpers.print_box(:info, message, message_output)
        end

        def warning(message)
          MessageHelpers.print_box(:warn, message, message_output)
        end

        def error(message)
          MessageHelpers.print_box(:error, message, message_output)
        end

        def success(message)
          MessageHelpers.print_box(:success, message, message_output)
        end

        private

        def message_output
          (defined?(@err) && @err) || MessageHelpers.stderr
        end
      end

      self.stdout = $stdout
      self.stderr = $stderr
    end
  end
end
