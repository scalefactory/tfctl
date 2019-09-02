# frozen_string_literal: true

require 'open3'
require 'fileutils'
require 'shellwords'
require 'thread'
require_relative 'error.rb'

module Tfctl
    module Executor
        extend self

        # Execute terraform command
        def run(account_name:, config_name:, log:, cmd: nil, argv: [], unbuffered: true)

            if cmd.nil?
                if File.exists?("#{PROJECT_ROOT}/bin/terraform")
                    # use embedded terraform binary
                    cmd = "#{PROJECT_ROOT}/bin/terraform"
                else
                    cmd = 'terraform'
                end
            end

            path       = "#{PROJECT_ROOT}/.tfctl/#{config_name}/#{account_name}"
            cwd        = FileUtils.pwd
            plan_file  = "#{path}/tfplan"
            semaphore  = Mutex.new
            output     = []

            # Extract terraform sub command from argument list
            args       = Array.new(argv)
            subcmd     = args[0]
            args.delete_at(0)

            # Enable plan file for `plan` and `apply` sub commands
            args += plan_file_args(plan_file, subcmd)

            # Create the command
            exec = [cmd] + [subcmd] + args

            # Set environment variables for Terraform
            env = {
                'TF_INPUT'           => '0',
                'CHECKPOINT_DISABLE' => '1',
                'TF_IN_AUTOMATION'   => 'true',
                # 'TF_LOG'             => 'TRACE'
            }

            log.debug "#{account_name}: Executing: #{exec.shelljoin}"

            FileUtils.cd path
            Open3.popen3(env, exec.shelljoin) do |stdin, stdout, stderr, wait_thr|
                stdin.close_write

                # capture stdout and stderr in separate threads to prevent deadlocks
                Thread.new do
                    stdout.each do |line|
                        semaphore.synchronize do
                            unbuffered ? log.info("#{account_name}: #{line.chomp}") : output << [ 'info', line ]
                        end
                    end
                end
                Thread.new do
                    stderr.each do |line|
                        semaphore.synchronize do
                            unbuffered ? log.error("#{account_name}: #{line.chomp}") : output << [ 'error', line ]
                        end
                    end
                end

                status = wait_thr.value

                # log the output
                output.each do |line|
                    log.send(line[0], "#{account_name}: #{line[1].chomp}")
                end

                FileUtils.cd cwd
                FileUtils.rm_f plan_file if args[0] == 'apply' # tidy up the plan file

                unless status.exitstatus == 0
                    raise Tfctl::Error.new "#{cmd} failed with exit code: #{status.exitstatus}"
                end
            end
        end

        # Adds plan file to `plan` and `apply` sub commands
        def plan_file_args(plan_file, subcmd)
            output = []
            if subcmd == 'plan'
                output = [ "-out=#{plan_file}" ]

            elsif subcmd == 'apply'
                if File.exists?(plan_file)
                    output = [ "#{plan_file}" ]
                else
                    raise Tfctl::Error.new "Plan file not found in #{plan_file}.  Run plan first."
                end
            end
            output
        end
    end
end
