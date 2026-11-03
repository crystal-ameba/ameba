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

    # Whether the issue has been corrected in the source.
    getter? corrected : Bool

    delegate :enabled?, :disabled?,
      to: status

    def initialize(@code, @rule, @location, @end_location, @message, @status : Status = :enabled, @block : (Source::Corrector ->)? = nil, *, @corrected = false)
    end

    def syntax?
      rule.is_a?(Rule::Lint::Syntax)
    end

    def correctable?
      !@block.nil?
    end

    # Returns `true` if the issue still needs attention,
    # which is to say it's neither disabled nor corrected.
    def unresolved?
      enabled? && !corrected?
    end

    def correct(corrector)
      @block.try(&.call(corrector))
    end

    # Returns the same issue, marked as corrected in the source.
    def as_corrected : self
      self.class.new(code, rule, location, end_location, message, status, @block, corrected: true)
    end

    # Returns the same issue with the given *message*, but without the means
    # of correcting it.
    def without_correction(message = @message) : self
      self.class.new(code, rule, location, end_location, message, status)
    end
  end
end
