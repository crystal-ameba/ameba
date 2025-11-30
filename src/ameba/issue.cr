module Ameba
  # Represents an issue reported by Ameba.
  struct Issue
    enum Status
      Enabled
      Disabled
    end

    # The source code that triggered this issue.
    getter code : String

    # A rule that triggers this issue.
    getter rule : Rule::Base

    # Location of the issue.
    getter location : Crystal::Location?

    # End location of the issue.
    getter end_location : Crystal::Location?

    # Issue message.
    getter message : String

    # Issue status.
    getter status : Status

    delegate :enabled?, :disabled?,
      to: status

    def initialize(@code, @rule, @location, @end_location, @message, status : Status? = nil, @block : (Source::Corrector ->)? = nil)
      @status = status || Status::Enabled
    end

    def syntax?
      rule.is_a?(Rule::Lint::Syntax)
    end

    def correctable?
      !@block.nil?
    end

    def correct(corrector)
      @block.try &.call(corrector)
    end
  end
end
