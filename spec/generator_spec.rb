# frozen_string_literal: true

require_relative '../lib/tfctl/config.rb'
require_relative '../lib/tfctl/generator.rb'

RSpec.describe Tfctl::Generator do
    # test data
    def yaml_config
        YAML.safe_load(File.read("#{PROJECT_ROOT}/spec/data/config.yaml")).symbolize_names!
    end

    def aws_org_config
        # rubocop:disable Security/YAMLLoad
        YAML.load(File.read("#{PROJECT_ROOT}/spec/data/aws_org.yaml"))
        # rubocop:enable Security/YAMLLoad
    end


    before(:all) do
        @config = Tfctl::Config.new(
            config_name:    'test',
            yaml_config:    yaml_config,
            aws_org_config: aws_org_config,
        )
        @account = @config[:accounts][0]
        @generated_dir = "#{PROJECT_ROOT}/.tfctl/#{@config[:config_name]}/#{@account[:name]}"

        Tfctl::Generator.make(
            config:  @config,
            account: @account,
        )
    end

    it 'generates valid provider resource' do
        file = File.read("#{@generated_dir}/provider.tf.json")
        provider = JSON.parse(file)['provider']

        expect(provider['aws']['version']).to eq(@config[:aws_provider_version])
        expect(provider['aws']['region']).to eq(@account[:region])
        expect(provider['aws']['assume_role']['role_arn']).to eq("arn:aws:iam::#{@account[:id]}:role/#{@account[:tf_execution_role]}")
    end

    it 'generates valid terraform resource' do
        file = File.read("#{@generated_dir}/terraform.tf.json")
        terraform = JSON.parse(file)['terraform']

        expect(terraform['required_version']).to eq(@config[:tf_required_version])
        expect(terraform['backend']['s3']['bucket']).to eq(@config[:tf_state_bucket])
        expect(terraform['backend']['s3']['key']).to eq("#{@account[:name]}/tfstate")
        expect(terraform['backend']['s3']['region']).to eq(@account[:region])
        expect(terraform['backend']['s3']['role_arn']).to eq(@config[:tf_state_role_arn])
        expect(terraform['backend']['s3']['dynamodb_table']).to eq(@config[:tf_state_dynamodb_table])
        expect(terraform['backend']['s3']['encrypt']).to eq('true')
    end

    it 'generates valid variables' do
        file = File.read("#{@generated_dir}/vars.tf.json")
        variable = JSON.parse(file)['variable']

        expect(variable['config']['type']).to eq('string')
    end

    it 'generates valid profile module' do
        profile_name = @account[:profiles][0]
        file = File.read("#{@generated_dir}/profile_#{profile_name}.tf.json")
        profile_module = JSON.parse(file)['module']

        expect(profile_module[profile_name]['source']).to eq("../../../profiles/#{profile_name}")
        expect(profile_module[profile_name]['config']).to eq('${var.config}')
        expect(profile_module[profile_name]['providers']['aws']).to eq('aws')
    end

    it 'generates valid config auto tfvars' do
        file = File.read("#{@generated_dir}/config.auto.tfvars.json")
        config_var = JSON.parse(file)['config']

        expect(config_var).to eq(@config.to_json)
    end
end
