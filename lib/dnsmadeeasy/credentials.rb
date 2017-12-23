require 'yaml'
require 'dnsmadeeasy'
require 'hashie/extensions/mash/symbolize_keys'
require 'sym'

require_relative 'credentials/api_keys'
require_relative 'credentials/yaml_file'

module DnsMadeEasy
  # A Facade module
  #
  # ## Usage
  #
  #         @creds = DnsMadeEasy::Credentials.create(key, secret)
  #         @creds.api_key #=> ...
  #         @creds.api_secret # > ...
  #
  # ### From a single-level YAML file that looks like this:
  #
  # ```yaml
  # credentials:
  #    api_key: 12345678-a8f8-4466-ffff-2324aaaa9098
  #    api_secret: 43009899-abcc-ffcc-eeee-09f809808098
  # ````
  #
  #         @creds = DnsMadeEasy::Credentials.keys_from_file(filename: file)
  #         @creds.api_key #=> '12345678-a8f8-4466-ffff-2324aaaa9098'
  #
  # #### From a default filename ~/.dnsmadeeasy/credentials.yml
  #
  #         @creds = DnsMadeEasy::Credentials.keys_from_file
  #
  # ### From a multi-account file
  #
  # Multi-account YAML file must look like this:
  #
  # ```yaml
  # accounts:
  #   - name: production
  #     default_account: true
  #     credentials:
  #       api_key: "BAhTOh1TeW06OkRhdGE6OldyYXBwZXJTdHJ1Y3QLOhNlbmNyeXB0ZWRfZGF0YSJV9HFDvF4KUwQLqevf4zvsKO1Yk04kRimAHAfNgoFO0dtRb6OjREyI43uzFV7z63FGjzXcBBG9KDUdj6OowbDw2z86nkTpakkKuIP31HCPZkQ6B2l2IhV2LPWTPSfDruDxi_ToEfbQOhBjaXBoZXJfbmFtZSIQQUVTLTI1Ni1DQkM6CXNhbHQwOgx2ZXJzaW9uaQY6DWNvbXByZXNzVA=="
  #       api_secret: "BAhTOh1TeW06OkRhdGE6OldyYXBwZXJTdHJ1Y3QLOhNlbmNyeXB0ZWRfZGF0YSJVHE1D3mpTsUseEdm3NWox7xdeQExobVx3-dHnEJoK9XYXawoPvtgroxOhsaYxZtxz_ZeHtSDZwu0eyDVyZ-XDo-vxalo9cQ2FOm05hVQaebo6B2l2IhVosiRfW5FnRK4BxfwPytLcOhBjaXBoZXJfbmFtZSIQQUVTLTI1Ni1DQkM6CXNhbHQwOgx2ZXJzaW9uaQY6DWNvbXByZXNzVA=="
  #       encryption_key: spec/fixtures/sym.key
  #   - name: preview
  #     credentials:
  #       api_key: "BAhTOh1TeW06OkRhdGE6OldyYXBwZXJTdHJ1Y3QLOhNlbmNyeXB0ZWRfZGF0YSJV9HFDvF4KUwQLqevf4zvsKO1Yk04kRimAHAfNgoFO0dtRb6OjREyI43uzFV7z63FGjzXcBBG9KDUdj6OowbDw2z86nkTpakkKuIP31HCPZkQ6B2l2IhV2LPWTPSfDruDxi_ToEfbQOhBjaXBoZXJfbmFtZSIQQUVTLTI1Ni1DQkM6CXNhbHQwOgx2ZXJzaW9uaQY6DWNvbXByZXNzVA=="
  #       api_secret: "BAhTOh1TeW06OkRhdGE6OldyYXBwZXJTdHJ1Y3QLOhNlbmNyeXB0ZWRfZGF0YSJVHE1D3mpTsUseEdm3NWox7xdeQExobVx3-dHnEJoK9XYXawoPvtgroxOhsaYxZtxz_ZeHtSDZwu0eyDVyZ-XDo-vxalo9cQ2FOm05hVQaebo6B2l2IhVosiRfW5FnRK4BxfwPytLcOhBjaXBoZXJfbmFtZSIQQUVTLTI1Ni1DQkM6CXNhbHQwOgx2ZXJzaW9uaQY6DWNvbXByZXNzVA=="
  #       encryption_key:
  #   - name: staging
  #     credentials:
  #       api_key: 12345678-a8f8-4466-ffff-2324aaaa9098
  #       api_secret: 43009899-abcc-ffcc-eeee-09f809808098
  #
  # ```
  #
  # Here we have multiple credentials account, one of which can have 'default_account: true'
  # Each account has a name that's used in `account_name` argument. Finally, if the keys
  # are encrypted, the key can either be referenced in the YAML file itself (in the above
  # case it points to a file name — see documentation on the gem Sym about various formats
  # of the key).
  #
  # Note that in this case, encryption key is optional, since the YAML file
  # actually specifies the key.
  #
  #         @creds = DnsMadeEasy::Credentials.keys_from_file(
  #                            filename: 'spec/fixtures/credentials-multi-account.yml',
  #                            account_name: 'production')
  #
  #
  # )

  module Credentials

    class << self

      # Create a new instance of Credentials::ApiKeys
      def create(key, secret, encryption_key = nil)
        ApiKeys.new(key, secret, encryption_key)
      end

      def keys_from_file(filename: default_credentials_path,
                         account_name: nil,
                         encryption_key: nil)

        YamlFile.new(filename: filename).keys(account_name:   account_name,
                                    encryption_key: encryption_key)
      end

      # @return String path to the default credentials file.
      def default_credentials_path(user: nil)
        user ?
          File.expand_path(Dir.home(user) + '/.dnsmadeeasy/credentials.yml').freeze :
          File.expand_path('~/.dnsmadeeasy/credentials.yml').freeze
      end
    end
  end
end
