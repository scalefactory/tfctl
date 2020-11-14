# frozen_string_literal: true

require 'json_schemer'
require_relative 'error'

# Config validator using JSON schema

module Tfctl
    module Schema
        class << self

            def validate(data)
                schemer = JSONSchemer.schema(main_schema)
                issues = []
                schemer.validate(data).each do |issue|
                    issues << {
                        details:      issue['details'],
                        data_pointer: issue['data_pointer'],
                    }
                end

                return if issues.empty?

                raise Tfctl::ValidationError.new('Config validation failed', issues)
            end

            private

            def main_schema
                iam_arn_pattern = 'arn:aws:iam:[a-z\-0-9]*:[0-9]{12}:[a-zA-Z\/+@=.,]*'

                # rubocop:disable Layout/HashAlignment
                {
                    'type'       => 'object',
                    'properties' => {
                        'tf_state_bucket'         => { 'type' => 'string' },
                        'tf_state_role_arn'       => {
                            'type'    => 'string',
                            'pattern' => iam_arn_pattern,
                        },
                        'tf_state_dynamodb_table' => { 'type' => 'string' },
                        'tf_state_region'         => { 'type' => 'string' },
                        'tf_required_version'     => { 'type' => 'string' },
                        'aws_provider_version'    => { 'type' => 'string' },
                        'tfctl_role_arn'          => {
                            'type'    => 'string',
                            'pattern' => iam_arn_pattern,
                        },
                        'data'                    => { 'type' => 'object' },
                        'exclude_accounts'        => { 'type' => 'array' },
                        'organization_root'       => org_schema,
                        'organization_units'      => org_schema,
                        'account_overrides'       => org_schema,
                    },
                    'required'   => %w[
                        tf_state_bucket
                        tf_state_role_arn
                        tf_state_dynamodb_table
                        tf_state_region
                        tfctl_role_arn
                    ],
                    'additionalProperties' => false,
                }
                # rubocop:enable Layout/HashAlignment
            end

            def org_schema
                {
                    'type'       => 'object',
                    'properties' => {
                        'profiles'          => { 'type'=> 'array' },
                        'data'              => { 'type'=> 'object' },
                        'tf_execution_role' => { 'type'=> 'string' },
                        'region'            => { 'type'=> 'string' },
                    },
                }
            end
        end
    end
end
