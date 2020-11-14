# frozen_string_literal: true

require 'yaml'
require_relative '../lib/hash'
require_relative '../lib/tfctl/schema'

RSpec.describe Tfctl::Schema do
    let(:yaml_config) do
        YAML.safe_load(File.read("#{PROJECT_ROOT}/spec/data/config.yaml"))
    end

    subject do
        Tfctl::Schema.validate(yaml_config)
    end

    it 'validates correct configuration' do
        expect { subject }.to_not raise_error
    end

    it 'fails when required parameter is missing' do
        yaml_config.delete('tf_state_bucket')
        expect { subject }.to raise_error Tfctl::ValidationError
    end

    it 'fails when parameter type is incorrect' do
        yaml_config['tf_state_region'] = 1
        expect { subject }.to raise_error Tfctl::ValidationError
    end

    it 'fails when string regex doesnt match' do
        yaml_config['tf_state_role_arn'] = 'some other string'
        expect { subject }.to raise_error Tfctl::ValidationError
    end

    it 'fails when unexpected parameters are found' do
        yaml_config['new_parameter'] = 'some value'
        expect { subject }.to raise_error Tfctl::ValidationError
    end

end
