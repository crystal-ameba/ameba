module Ameba
  # Represents an issue reported by Ameba.
  struct Issue
    enum Status
      Enabled
      Disabled
    end

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

    def initialize(@rule, @location, @end_location, @message, status : Status? = nil)
      @status = status || Status::Enabled
    end

    def syntax?
      rule.is_a?(Rule::Lint::Syntax)
    end
  end
end
