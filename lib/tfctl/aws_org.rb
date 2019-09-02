# frozen_string_literal: true

require_relative 'error.rb'
require 'aws-sdk-organizations'

module Tfctl
    class AwsOrg

        def initialize(role_arn)
            @aws_org_client = Aws::Organizations::Client.new(
              region:      'us-east-1',
              # Assume role in primary account to read AWS organization API
              credentials: aws_assume_role(role_arn)
            )
        end

        # Gets account data for specified OUs from AWS Organizations API
        def accounts(org_units)
            output = { :accounts => [] }

            aws_ou_ids = aws_ou_list

            org_units.each do |ou_path|

                if aws_ou_ids.has_key?(ou_path)
                    parent_id = aws_ou_ids[ou_path]
                else
                    raise Tfctl::Error.new "Error: OU: #{ou_path}, does not exists in AWS organization"
                end

                @aws_org_client.list_accounts_for_parent({ parent_id: parent_id }).accounts.each do |account|
                    if account.status == 'ACTIVE'

                        output[:accounts] << {
                            :name       => account.name,
                            :id         => account.id,
                            :arn        => account.arn,
                            :email      => account.email,
                            :ou_path    => ou_path.to_s,
                            :ou_parents => ou_path.to_s.split('/'),
                            :profiles   => [],
                        }
                    end
                end
            end
            output
        end

        private

        # Get a mapping of ou_name => ou_id from AWS organizations
        def aws_ou_list()
            output = {}
            root_ou_id = @aws_org_client.list_roots.roots[0].id

            ou_recurse = lambda do |ous|
                ous.each do |ou_name, ou_id|
                    children = aws_ou_list_children(ou_id, ou_name)
                    unless children.empty?
                        output.merge!(children)
                        ou_recurse.call(children)
                    end
                end
            end
            ou_recurse.call({ :root => root_ou_id })

            output
        end

        # Get a list of child ou's for a parent
        def aws_ou_list_children(parent_id, parent_name)
            output = {}
            retries = 0

            @aws_org_client.list_children( {
                child_type: 'ORGANIZATIONAL_UNIT',
                parent_id: parent_id,
            }).children.each do |child|

                begin
                    ou = @aws_org_client.describe_organizational_unit({
                        organizational_unit_id: child.id
                    }).organizational_unit
                rescue Aws::Organizations::Errors::TooManyRequestsException
                    # FIXME - use logger
                    puts 'AWS Organizations: too many requests.  Retrying in 5 secs.'
                    sleep 5
                    retries += 1
                    retry if retries < 10
                end

                if parent_name == :root
                    ou_name = ou.name.to_sym
                else
                    ou_name = "#{parent_name}/#{ou.name}".to_sym
                end

                output[ou_name] = ou.id
            end
            output
        end

        def aws_assume_role(role_arn)
          begin
            sts = Aws::STS::Client.new()

            role_credentials = Aws::AssumeRoleCredentials.new(
              client: sts,
              role_arn: role_arn,
              role_session_name: 'tfctl'
            )
          rescue StandardError => e
            raise Tfctl::Error.new("Error assuming role: #{role_arn}, #{e.message}")
            exit 1
          end

          role_credentials
        end

    end
end
