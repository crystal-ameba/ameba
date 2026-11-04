require "./ast/util"

module Ameba
  # Represents a module used to report issues.
  module Reportable
    include AST::Util

    # List of reported issues.
    getter issues = [] of Issue

    # Adds a new issue to the list of issues.
    def add_issue(rule,
                  location : Crystal::Location?,
                  end_location : Crystal::Location?,
                  message : String,
                  status : Issue::Status? = nil,
                  block : (Source::Corrector ->)? = nil) : Issue
      status ||=
        if location_disabled?(location, rule)
          Issue::Status::Disabled
        else
          Issue::Status::Enabled
        end

      Issue.new(code, rule, location, end_location, message, status, block).tap do |issue|
        issues << issue
      end
    end

    # :ditto:
    def add_issue(rule,
                  location : Crystal::Location?,
                  end_location : Crystal::Location?,
                  message : String,
                  status : Issue::Status? = nil,
                  &block : Source::Corrector ->) : Issue
      add_issue(rule, location, end_location, message, status, block)
    end

    # Adds a new issue for *location* defined by line and column numbers.
    def add_issue(rule,
                  location : {Crystal::Location, Crystal::Location},
                  message : String,
                  status : Issue::Status? = nil,
                  block : (Source::Corrector ->)? = nil) : Issue
      add_issue(rule, *location, message, status, block)
    end

    # Adds a new issue for Crystal AST *node*.
    def add_issue(rule,
                  node : Crystal::ASTNode,
                  message : String,
                  status : Issue::Status? = nil,
                  block : (Source::Corrector ->)? = nil,
                  *,
                  prefer_name_location = false) : Issue
      if prefer_name_location
        case node_location = name_location_or(node)
        when Tuple(Crystal::Location, Crystal::Location)
          location, end_location = node_location
        else
          location, end_location =
            name_location(node), name_end_location(node)
        end
      end

      location ||= node.location
      end_location ||= node.end_location

      add_issue(rule, location, end_location, message, status, block)
    end

    # :ditto:
    def add_issue(rule,
                  node : Crystal::ASTNode,
                  message : String,
                  status : Issue::Status? = nil,
                  *,
                  prefer_name_location = false,
                  &block : Source::Corrector ->) : Issue
      add_issue(rule, node, message, status, block, prefer_name_location: prefer_name_location)
    end

    # Adds a new issue for Crystal *token*.
    def add_issue(rule,
                  token : Crystal::Token,
                  message : String,
                  status : Issue::Status? = nil,
                  block : (Source::Corrector ->)? = nil) : Issue
      add_issue(rule, token.location, nil, message, status, block)
    end

    # :ditto:
    def add_issue(rule,
                  token : Crystal::Token,
                  message : String,
                  status : Issue::Status? = nil,
                  &block : Source::Corrector ->) : Issue
      add_issue(rule, token, message, status, block)
    end

    # Adds a new issue for *location* defined by line and column numbers.
    def add_issue(rule,
                  location : {Int32, Int32},
                  message : String,
                  status : Issue::Status? = nil,
                  block : (Source::Corrector ->)? = nil) : Issue
      location =
        Crystal::Location.new(path.to_s, *location)

      add_issue(rule, location, nil, message, status, block)
    end

    # :ditto:
    def add_issue(rule,
                  location : {Int32, Int32},
                  message : String,
                  status : Issue::Status? = nil,
                  &block : Source::Corrector ->) : Issue
      add_issue(rule, location, message, status, block)
    end

    # Adds a new issue for *location* and *end_location* defined by line and column numbers.
    def add_issue(rule,
                  location : {Int32, Int32},
                  end_location : {Int32, Int32},
                  message : String,
                  status : Issue::Status? = nil,
                  block : (Source::Corrector ->)? = nil) : Issue
      location =
        Crystal::Location.new(path.to_s, *location)
      end_location =
        Crystal::Location.new(path.to_s, *end_location)

      add_issue(rule, location, end_location, message, status, block)
    end

    # :ditto:
    def add_issue(rule,
                  location : {Int32, Int32},
                  end_location : {Int32, Int32},
                  message : String,
                  status : Issue::Status? = nil,
                  &block : Source::Corrector ->) : Issue
      add_issue(rule, location, end_location, message, status, block)
    end

    # Adds an issue reporting a failure which isn't about the code itself. It
    # can't be disabled, as nothing else would tell that something went wrong.
    def add_crash_issue(rule, message : String) : Nil
      issue = add_issue(rule, {1, 1}, message, status: :enabled)
      issues[-1] = issue.as_crashed
    end

    # Returns the issues which still need attention.
    def unresolved_issues
      issues.select(&.unresolved?)
    end

    # Returns `true` if no issue needs attention anymore, `false` otherwise.
    def valid?
      issues.none?(&.unresolved?)
    end
  end
end
