# frozen_string_literal: true

require 'fileutils'

# Generates top level Terraform configuration for an account.

module Tfctl
    module Generator
        module_function

        def write_json_block(path, block)
            File.open(path, 'w') do |f|
                f.write("#{JSON.pretty_generate(block)}\n")
            end
        end

        def make(account:, config:)
            target_dir = "#{PROJECT_ROOT}/.tfctl/#{config[:config_name]}/#{account[:name]}"
            tf_state_prefix = config.fetch(:tf_state_prefix, '').delete_suffix('/')
            tf_version = config.fetch(:tf_required_version, '>= 0.12.29')
            aws_provider_version = config.fetch(:aws_provider_version, '>= 2.14')

            FileUtils.mkdir_p target_dir

            terraform_block = {
                'terraform' => {
                    'required_version'   => tf_version,
                    'required_providers' => {
                        'aws' => {
                            'source'  => 'hashicorp/aws',
                            'version' => aws_provider_version,
                        },
                    },
                    'backend'            => {
                        's3' => {
                            'bucket'         => config[:tf_state_bucket],
                            'key'            => [tf_state_prefix, account[:name], 'tfstate'].join('/').delete_prefix('/'),
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
                        'region'       => account[:region],
                        'assume_role'  => {
                            'role_arn' => "arn:aws:iam::#{account[:id]}:role/#{account[:tf_execution_role]}",
                        },
                        'default_tags' => {
                            'tags' => config.fetch(:default_tags, {}),
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

            account[:profiles].each do |profile|
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
