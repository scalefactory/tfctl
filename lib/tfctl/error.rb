# frozen_string_literal: true

module Tfctl
    class Error < StandardError
    end

    class ValidationError < StandardError
        attr_reader :issues

        def initialize(message, issues = [])
            super(message)
            @issues = issues
        end
    end
end
