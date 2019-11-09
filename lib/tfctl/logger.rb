# frozen_string_literal: true

require 'logger'

module Tfctl
    class Logger

        def initialize(log_level)
            @outlog  = ::Logger.new(STDOUT)

            self.level = log_level

            @outlog.formatter = proc do |severity, _datetime, _progname, msg|
                # "#{datetime.iso8601} #{severity.downcase}: #{msg}\n"
                "#{severity.downcase}: #{msg}\n"
            end
        end

        def level=(level)
            @outlog.level = level
        end

        def level
            @outlog.level
        end

        def debug(msg)
            log(:debug, msg)
        end

        def info(msg)
            log(:info, msg)
        end

        def warn(msg)
            log(:warn, msg)
        end

        def error(msg)
            log(:error, msg)
        end

        def fatal(msg)
            log(:fatal, msg)
        end

        def log(level, msg)
            @outlog.send(level, msg)
        end

    end
end
