module Ameba
  # Represents an issue reported by Ameba.
  struct Issue
    enum Status
      Enabled
      Disabled
    end

    # What became of the issue, once the source got processed.
    enum Outcome
      # The issue still awaits being dealt with.
      Pending

      # The issue has been corrected in the source.
      Corrected

      # The issue reports an exception raised by its rule or correction, corrections
      # getting stuck in a loop, or a file which can't be read or written.
      Crashed
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

    # What became of the issue.
    getter outcome : Outcome

    delegate :enabled?, :disabled?,
      to: status

    delegate :corrected?, :crashed?,
      to: outcome

    def initialize(@code, @rule, @location, @end_location, @message, @status : Status = :enabled, @block : (Source::Corrector ->)? = nil, *, @outcome = Outcome::Pending)
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
      copy_with(outcome: :corrected)
    end

    # Returns the same issue with the given *message* and *outcome*, but without
    # the means of correcting it.
    def without_correction(message = @message, *, outcome : Outcome = :pending) : self
      copy_with(message: message, block: nil, outcome: outcome)
    end

    private def copy_with(*, message = @message, block = @block, outcome : Outcome = @outcome)
      self.class.new(code, rule, location, end_location, message, status, block, outcome: outcome)
    end
  end
end
