# frozen_string_literal: true

require_relative '../hash.rb'
require_relative 'error.rb'
require 'yaml'
require 'json'

module Tfctl
    class Config
        include Enumerable
        attr_reader :config

        def initialize(config_name:, yaml_config:, aws_org_config:, use_cache: false)
            cache_file  = "#{PROJECT_ROOT}/.tfctl/#{config_name}_cache.yaml"

            # Get configuration.  Either load from cache or process fresh.
            if use_cache
                @config = read_cache(cache_file)
            else
                @config = load_config(config_name, yaml_config, aws_org_config)
                write_cache(@config, cache_file)
            end
        end

        def [](key)
            @config[key]
        end

        def each(&block)
            @config.each(&block)
        end

        def has_key?(k)
            @config.has_key?(k)
        end

        def to_yaml
            @config.to_yaml
        end

        def to_json
            @config.to_json
        end

        # Filters accounts by account property
        def find_accounts(property_name, property_value)
            output =[]
            @config[:accounts].each do |account|
                if account[property_name] == property_value
                    output << account
                end
            end

            if output.empty?
                raise Tfctl::Error.new "Account not found with #{property_name}: #{property_value}"
            end
            output
        end

        def find_accounts_regex(property_name, expr)
            output =[]
            @config[:accounts].each do |account|
                begin
                    if account[property_name] =~ /#{expr}/
                        output << account
                    end
                rescue RegexpError => e
                    raise Tfctl::Error.new "Regexp: #{e}"
                end
            end

            if output.empty?
                raise Tfctl::Error.new "Account not found with #{property_name} matching regex: #{expr}"
            end
            output
        end


        private

        # Retrieves AWS Organizations data and merges it with data from yaml config.
        def load_config(config_name, yaml_config, aws_org_config)

            # AWS Organizations data
            config = aws_org_config
            # Merge organization sections from yaml file
            config = merge_accounts_config(config, yaml_config)
            # Import remaining parameters from yaml file
            config = import_yaml_config(config, yaml_config)
            # Set excluded property on any excluded accounts
            config = mark_excluded_accounts(config)
            # Remove any profiles that are unset
            config = remove_unset_profiles(config)
            # Set config name property (based on yaml config file name)
            config[:config_name] = config_name
            config
        end

        def write_cache(config, cache_file)
            FileUtils.mkdir_p File.dirname(cache_file)
            File.open(cache_file, 'w') {|f| f.write self.to_yaml }
        end

        def read_cache(cache_file)
            unless File.exist?(cache_file)
                raise Tfctl::Error.new("Cached configuration not found in: #{cache_file}")
            end

            YAML.load_file(cache_file)
        end

        # Sets :excluded property on any excluded accounts
        def mark_excluded_accounts(config)
          return config unless config.has_key?(:exclude_accounts)

          config[:accounts].each_with_index do |account, idx|
              if config[:exclude_accounts].include?(account[:name])
                  config[:accounts][idx][:excluded] = true
              else
                  config[:accounts][idx][:excluded] = false
              end
          end
          config
        end

        def remove_unset_profiles(config)
            config[:accounts].each do |account|
                profiles_to_unset = []
                account[:profiles].each do |profile|
                    if profile =~  /\.unset$/
                        profiles_to_unset << profile
                        profiles_to_unset << profile.chomp('.unset')
                    end
                end
                account[:profiles] = account[:profiles] - profiles_to_unset
            end
            config
        end

        # Import yaml config other than organisation defaults sections which are merged elsewhere.
        def import_yaml_config(config, yaml_config)
            yaml_config.delete(:organization_root)
            yaml_config.delete(:organization_units)
            yaml_config.delete(:account_overrides)
            config.merge(yaml_config)
        end

        # Merge AWS Organizations accounts config with defaults from yaml config
        def merge_accounts_config(config, yaml_config)

            config[:accounts].each_with_index do |account_config, idx|
                account_name       = account_config[:name].to_sym
                account_ou_parents = account_config[:ou_parents]

                # merge any root settings
                account_config = account_config.deep_merge(yaml_config[:organization_root])

                # merge all OU levels settings
                account_ou_parents.each_with_index do |_, i|
                    account_ou = account_ou_parents[0..i].join('/').to_sym
                    if yaml_config[:organization_units].has_key?(account_ou)
                        account_config = account_config.deep_merge(yaml_config[:organization_units][account_ou])
                    end
                end

                # merge any account overrides
                if yaml_config[:account_overrides].has_key?(account_name)
                    account_config = account_config.deep_merge(yaml_config[:account_overrides][account_name])
                end

                config[:accounts][idx] = account_config
            end
            config
        end

    end
end
