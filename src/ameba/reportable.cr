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
        Issue::Status::Disabled if location_disabled?(location, rule)

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
      add_issue rule, location, end_location, message, status, block
    end

    # Adds a new issue for Crystal AST *node*.
    def add_issue(rule, node : Crystal::ASTNode, message, status : Issue::Status? = nil, block : (Source::Corrector ->)? = nil, *, prefer_name_location = false) : Issue
      location = name_location(node) if prefer_name_location
      location ||= node.location

      end_location = name_end_location(node) if prefer_name_location
      end_location ||= node.end_location

      add_issue rule, location, end_location, message, status, block
    end

    # :ditto:
    def add_issue(rule, node : Crystal::ASTNode, message, status : Issue::Status? = nil, *, prefer_name_location = false, &block : Source::Corrector ->) : Issue
      add_issue rule, node, message, status, block, prefer_name_location: prefer_name_location
    end

    # Adds a new issue for Crystal *token*.
    def add_issue(rule, token : Crystal::Token, message, status : Issue::Status? = nil, block : (Source::Corrector ->)? = nil) : Issue
      add_issue rule, token.location, nil, message, status, block
    end

    # :ditto:
    def add_issue(rule, token : Crystal::Token, message, status : Issue::Status? = nil, &block : Source::Corrector ->) : Issue
      add_issue rule, token, message, status, block
    end

    # Adds a new issue for *location* defined by line and column numbers.
    def add_issue(rule, location : {Int32, Int32}, message, status : Issue::Status? = nil, block : (Source::Corrector ->)? = nil) : Issue
      location =
        Crystal::Location.new(path, *location)

      add_issue rule, location, nil, message, status, block
    end

    # :ditto:
    def add_issue(rule, location : {Int32, Int32}, message, status : Issue::Status? = nil, &block : Source::Corrector ->) : Issue
      add_issue rule, location, message, status, block
    end

    # Adds a new issue for *location* and *end_location* defined by line and column numbers.
    def add_issue(rule,
                  location : {Int32, Int32},
                  end_location : {Int32, Int32},
                  message,
                  status : Issue::Status? = nil,
                  block : (Source::Corrector ->)? = nil) : Issue
      location =
        Crystal::Location.new(path, *location)
      end_location =
        Crystal::Location.new(path, *end_location)

      add_issue rule, location, end_location, message, status, block
    end

    # :ditto:
    def add_issue(rule,
                  location : {Int32, Int32},
                  end_location : {Int32, Int32},
                  message,
                  status : Issue::Status? = nil,
                  &block : Source::Corrector ->) : Issue
      add_issue rule, location, end_location, message, status, block
    end

    # Returns `true` if the list of not disabled issues is empty, `false` otherwise.
    def valid?
      issues.none?(&.enabled?)
    end
  end
end
