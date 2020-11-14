# frozen_string_literal: true

require 'open3'
require 'fileutils'
require 'shellwords'
require_relative 'error'

module Tfctl
    module Executor
        module_function

        # Execute terraform command
        def run(account_name:, config_name:, log:, cmd: nil, argv: [], unbuffered: true)

            # Use bin/terraform from a project dir if available
            # Otherwise rely on PATH.
            if cmd.nil?
                cmd = File.exist?("#{PROJECT_ROOT}/bin/terraform") ? "#{PROJECT_ROOT}/bin/terraform" : 'terraform'
            end

            # Fail if there are no arguments for terraform and show terraform -help
            if argv.empty?
                help = `#{cmd} -help`.lines.to_a[1..-1].join
                raise Tfctl::Error, "Missing terraform command.\n #{help}"
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
                            unbuffered ? log.info("#{account_name}: #{line.chomp}") : output << ['info', line]
                        end
                    end
                end
                Thread.new do
                    stderr.each do |line|
                        semaphore.synchronize do
                            unbuffered ? log.error("#{account_name}: #{line.chomp}") : output << ['error', line]
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

                unless status.exitstatus.zero?
                    raise Tfctl::Error, "#{cmd} failed with exit code: #{status.exitstatus}"
                end
            end
        end

        # Adds plan file to `plan` and `apply` sub commands
        def plan_file_args(plan_file, subcmd)
            return ["-out=#{plan_file}"] if subcmd == 'plan'

            if subcmd == 'apply'
                raise Tfctl::Error, "Plan file not found in #{plan_file}.  Run plan first." unless File.exist?(plan_file)

                return [plan_file.to_s]
            end

            return []
        end
    end
end
