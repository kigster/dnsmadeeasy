# frozen_string_literal: true

require 'dry/cli'
require 'awesome_print'
require 'json'
require 'yaml'
require 'dnsmadeeasy/cli/message_helpers'

module DnsMadeEasy
  module CLI
    module Commands
      # Base class for dry-cli commands.
      class Base < Dry::CLI::Command
        include MessageHelpers

        SUPPORTED_FORMATS = %w[json json_pretty yaml pp].freeze
        DEFAULT_CREDENTIAL_PATHS = [
          Pathname.new('~/.dnsmadeeasy/credentials.ini').expand_path,
          Pathname.new('./.dnsmadeeasy/credential.ini').expand_path
        ].freeze

        option :format, values: SUPPORTED_FORMATS, required: false, desc: 'Output format'
        option :credentials, required: false, desc: 'Path to credentials INI file'
        option :api_key, required: false, desc: 'DNS Made Easy API key'
        option :api_secret, required: false, desc: 'DNS Made Easy API secret'

        private

        def puts(*)
          @out.puts(*)
        end

        def warn(*)
          @err.puts(*)
        end

        def print_formatted(result, format = nil)
          case format&.to_sym
          when :json
            puts JSON.generate(result)
          when :json_pretty
            puts JSON.pretty_generate(result)
          when :yaml
            puts result.to_yaml
          when :pp
            require 'pp'
            puts PP.pp(result, +'')
          else
            @out.puts(result.ai(indent: 10))
          end
        end

        def configure_authentication(credentials: nil, api_key: nil, api_secret: nil)
          resolved_api_key, resolved_api_secret = resolve_credentials(
            credentials: credentials,
            api_key: api_key,
            api_secret: api_secret
          )

          DnsMadeEasy.api_key = resolved_api_key
          DnsMadeEasy.api_secret = resolved_api_secret
        end

        def resolve_credentials(credentials: nil, api_key: nil, api_secret: nil)
          return explicit_api_credentials(api_key, api_secret) if api_key || api_secret
          return credentials_from_ini(Pathname.new(credentials).expand_path) if credentials
          return [ENV.fetch('DNSMADEEASY_API_KEY'), ENV.fetch('DNSMADEEASY_API_SECRET')] if env_credentials?

          default_credentials_path = DEFAULT_CREDENTIAL_PATHS.find(&:exist?)
          return credentials_from_ini(default_credentials_path) if default_credentials_path

          raise DnsMadeEasy::APIKeyAndSecretMissingError, 'DNS Made Easy credentials were not found'
        end

        def explicit_api_credentials(api_key, api_secret)
          raise DnsMadeEasy::APIKeyAndSecretMissingError, '--api-key and --api-secret must be provided together' unless api_key && api_secret

          [api_key, api_secret]
        end

        def env_credentials?
          ENV.fetch('DNSMADEEASY_API_KEY', nil) && ENV.fetch('DNSMADEEASY_API_SECRET', nil)
        end

        def credentials_from_ini(path)
          raise DnsMadeEasy::APIKeyAndSecretMissingError, "Credentials file #{path} does not exist" unless path.exist?

          credentials = parse_ini_credentials(path)
          api_key = credentials['api_key'] || credentials['dns_dnsmadeeasy_api_key']
          api_secret = credentials['api_secret'] || credentials['dns_dnsmadeeasy_secret_key']
          explicit_api_credentials(api_key, api_secret)
        end

        def parse_ini_credentials(path)
          path.each_line.with_object({}) do |line, credentials|
            key, value = parse_ini_line(line)
            credentials[key] = value if key && value
          end
        end

        def parse_ini_line(line)
          stripped_line = line.strip
          return nil if ignored_ini_line?(stripped_line)

          key, value = stripped_line.split('=', 2).map(&:strip)
          [key, unquote_ini_value(value)]
        end

        def ignored_ini_line?(stripped_line)
          stripped_line.empty? || stripped_line.start_with?('#', ';', '[')
        end

        def unquote_ini_value(value)
          value&.delete_prefix('"')&.delete_suffix('"')
        end
      end
    end
  end
end
