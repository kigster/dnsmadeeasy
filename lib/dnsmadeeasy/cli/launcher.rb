# frozen_string_literal: true

require 'dry/cli'
require 'dnsmadeeasy/version'
require 'dnsmadeeasy/cli/commands'
require 'dnsmadeeasy/cli/input'

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
        return print_account_operation_help if account_operation_help?

        Input.stdin = stdin
        command.call(arguments: argv, out: stdout, err: stderr)
        0
      rescue SystemExit => e
        e.status
      rescue ReportedError
        1
      rescue StandardError => e
        stderr.puts(e.message)
        1
      end

      private

      def account_operation_help?
        argv.first == 'account' && argv[1] && !argv[1].start_with?('-') && argv.intersect?(%w[--help -h])
      end

      def print_account_operation_help
        stdout.puts Commands::Account.operation_help(argv[1])
        0
      end

      def command
        @command ||= Dry::CLI.new(Commands)
      end
    end
  end
end
