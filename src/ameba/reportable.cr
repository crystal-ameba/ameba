module Ameba
  # Represents a module used to report issues.
  module Reportable
    # List of reported issues.
    getter issues = [] of Issue

    # Adds a new issue to the list of issues.
    def add_issue(rule, location, end_location, message, status = nil)
      status ||= :disabled if location_disabled?(location, rule.name)
      issues << Issue.new rule, location, end_location, message, status
    end

    # Adds a new issue for AST *node*.
    def add_issue(rule, node, message, **args)
      add_issue rule, node.location, node.end_location, message, **args
    end

    # Adds a new issue for Crystal *token*.
    def add_issue(rule, token, message, **args)
      add_issue rule, token.location, nil, message, **args
    end

    # Adds a new issue for *location* defined by line and column numbers.
    def add_issue(rule, location : Tuple(Int32, Int32), message, **args)
      location = Crystal::Location.new path, *location
      add_issue rule, location, nil, message, **args
    end

    # Returns true if the list of not disabled issues is empty, false otherwise.
    def valid?
      issues.reject(&.disabled?).empty?
    end
  end
end
