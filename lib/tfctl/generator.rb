# frozen_string_literal: true

require 'fileutils'

# Generates top level Terraform configuration for an account.

module Tfctl
    module Generator
        module_function

        def write_json_block(path, block)
            File.open(path, 'w') do |f|
                f.write(JSON.pretty_generate(block) + "\n")
            end
        end

        def make(
            account_id:,
            account_name:,
            execution_role:,
            profiles:,
            config:,
            region:,
            tf_version: '>= 0.12.0',
            aws_provider_version: '~> 2.14',
            target_dir: "#{PROJECT_ROOT}/.tfctl/#{config[:config_name]}/#{account_name}"
        )

            FileUtils.mkdir_p target_dir

            terraform_block = {
                'terraform' => {
                    'required_version' => tf_version,
                    'backend'          => {
                        's3' => {
                            'bucket'         => config[:tf_state_bucket],
                            'key'            => "#{account_name}/tfstate",
                            'region'         => config[:tf_state_region],
                            'role_arn'       => config[:tf_state_role_arn],
                            'dynamodb_table' => config[:tf_state_dynamodb_table],
                            'encrypt'        => 'true',
                        },
                    },
                },
            }
            write_json_block("#{target_dir}/terraform.tf.json", terraform_block)

            provider_block = {
                'provider' => {
                    'aws' => {
                        'version'     => aws_provider_version,
                        'region'      => region,
                        'assume_role' => {
                            'role_arn' => "arn:aws:iam::#{account_id}:role/#{execution_role}",
                        },
                    },
                },
            }
            write_json_block("#{target_dir}/provider.tf.json", provider_block)

            vars_block = {
                'variable' => {
                    'config' => {
                        'type' => 'string',
                    },
                },
            }
            write_json_block("#{target_dir}/vars.tf.json", vars_block)

            # config is passed to profiles as a json encoded string.  It can be
            # decoded in profile using jsondecode() function.
            config_block = { 'config' => config.to_json }
            write_json_block("#{target_dir}/config.auto.tfvars.json", config_block)

            FileUtils.rm Dir.glob("#{target_dir}/profile_*.tf.json")

            profiles.each do |profile|
                profile_block = {
                    'module' => {
                        profile => {
                            'source'    => "../../../profiles/#{profile}",
                            'config'    => '${var.config}',
                            'providers' => {
                                'aws' => 'aws',
                            },
                        },
                    },
                }

                write_json_block("#{target_dir}/profile_#{profile}.tf.json", profile_block)
            end

        end
    end
end
