# frozen_string_literal: true

require_relative '../lib/tfctl/config'

RSpec.describe Tfctl::Config do
    # test data
    def yaml_config
        YAML.safe_load(File.read("#{PROJECT_ROOT}/spec/data/config.yaml"),  aliases: true).symbolize_names!
    end

    def aws_org_config
        # rubocop:disable Security/YAMLLoad
        YAML.load(File.read("#{PROJECT_ROOT}/spec/data/aws_org.yaml"))
        # rubocop:enable Security/YAMLLoad
    end

    subject(:config) do
        Tfctl::Config.new(
            config_name:    'test',
            yaml_config:    yaml_config,
            aws_org_config: aws_org_config,
        )
    end

    it 'sets config name' do
        expect(config[:config_name]).to eq('test')
    end

    it 'contains root parameters' do
        yaml = yaml_config

        # remove merged parameters
        yaml.delete(:organization_root)
        yaml.delete(:organization_units)
        yaml.delete(:account_overrides)

        # check all the other's are present
        yaml.each do |k, v|
            expect(config[k]).to eq(v)
        end
    end

    it 'merges organization root parameters with all accounts' do
        root_params = yaml_config[:organization_root]

        config[:accounts].each do |account|
            root_params.each do |k, v|
                next if k == :data # overriden on some levels

                if k == :profiles
                    root_params[:profiles].each do |profile|
                        expect(account[:profiles]).to include(profile)
                    end
                else
                    expect(account[k]).to eq(v)
                end
            end
        end
    end

    it 'excludes account parameters from root config' do
        expect(config).not_to have_key(:organization_root)
        expect(config).not_to have_key(:organization_units)
        expect(config).not_to have_key(:account_overrides)
    end

    it 'adds profiles from all hierarchy levels to accounts' do
        root_profiles = ['global']
        team_profiles = ['team-shared']
        team_live_profiles = root_profiles + team_profiles + ['team-live']
        team_test_profiles = root_profiles + team_profiles + ['team-test']
        team_live_1_profiles = team_live_profiles + ['team-live-1']

        config[:accounts].each do |account|
            if account[:ou_path] == 'core'
                expect(account[:profiles]).to match_array(root_profiles)
            end
            if account[:name] == 'team-live-1'
                expect(account[:profiles]).to match_array(team_live_1_profiles)
            end
            if account[:name] == 'team-live-2'
                expect(account[:profiles]).to match_array(team_live_profiles)
            end
            if account[:name] == 'team-test-1'
                expect(account[:profiles]).to match_array(team_test_profiles)
            end
            if account[:name] == 'team-test-2'
                expect(account[:profiles]).to match_array(team_test_profiles)
            end
        end
    end

    it 'overrides parameters set lower in the hierarchy' do
        config[:accounts].each do |account|
            if account[:ou_path] == 'core'
                expect(account[:data][:root_param]).to eq('root')
                expect(account[:data]).not_to have_key(:team_param)
            end
            if account[:ou_path] == 'team/test'
                expect(account[:data][:team_param]).to eq('ou_override')
                expect(account[:data][:root_param]).to eq('ou_override')
            end
            if account[:name] == 'team-live-1'
                expect(account[:data][:root_param]).to eq('account_override')
                expect(account[:data][:team_param]).to eq('account_override')
            end
            if account[:name] == 'team-live-2'
                expect(account[:data][:root_param]).to eq('root')
                expect(account[:data][:team_param]).to eq('shared')
            end
        end
    end

    it 'merges account specific parameters' do
        config[:accounts].each do |account|
            if account[:name] == 'team-live-1'
                expect(account[:data][:account_param]).to eq('account')
            else
                expect(account[:data]).not_to have_key(:account_param)
            end
        end
    end

    it 'finds accounts by parameter name and value' do
        accounts = config.find_accounts(:name, 'team-live-1')
        expect(accounts[0][:name]).to eq('team-live-1')
        accounts = config.find_accounts(:ou_path, 'team/test')
        expect(accounts.length).to eq(2)
        accounts = config.find_accounts(:id, '6123456789')
        expect(accounts[0][:name]).to eq('team-test-1')
    end

    it 'finds accounts by parameter name and regex value' do
        accounts = config.find_accounts_regex(:ou_path, '.*/test')
        expect(accounts.length).to eq(2)
        accounts.each do |account|
            expect(account[:ou_parents]).to include('test')
            expect(account[:ou_parents]).not_to include('live')
            expect(account[:ou_parents]).not_to include('core')
        end
    end

    it 'flags excluded accounts' do
        config[:accounts].each do |account|
            if %w[primary security log-archive].include?(account[:name])
                expect(account[:excluded]).to eq(true)
            else
                expect(account[:excluded]).to eq(false)
            end
        end
    end

end
