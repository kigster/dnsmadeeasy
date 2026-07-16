# frozen_string_literal: true

require 'dry/cli'
require 'dnsmadeeasy/version'
require 'dnsmadeeasy/cli/commands'

module DnsMadeEasy
  module CLI
    # Entrypoint used by the executable and in-process CLI specs.
    class Launcher
      attr_reader :argv, :stdin, :stdout, :stderr, :kernel

      def initialize(argv, stdin = $stdin, stdout = $stdout, stderr = $stderr, kernel = Kernel)
        @argv = argv
        @stdin = stdin
        @stdout = stdout
        @stderr = stderr
        @kernel = kernel
      end

      def execute!
        command.call(arguments: argv, out: stdout, err: stderr)
      rescue SystemExit => e
        e.status
      end

      private

      def command
        @command ||= Dry::CLI.new(Commands)
      end
    end
  end
end
