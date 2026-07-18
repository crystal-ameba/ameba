require "./base"

module Ameba::Rule::Security
  # A rule that disallows SQL statements built from interpolated strings.
  #
  # Interpolating a value into a SQL statement makes it possible for
  # an attacker to read or modify data if the value is not trusted.
  #
  # For example, this is considered insecure:
  #
  # ```
  # db.query("SELECT * FROM users WHERE name = '#{name}'")
  # ```
  #
  # And should be written using query parameters:
  #
  # ```
  # db.query("SELECT * FROM users WHERE name = ?", name)
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Security/SqlInjection:
  #   Enabled: true
  # ```
  class SqlInjection < Base
    include AST::Util

    properties do
      since_version "1.7.0"
      description "Disallows SQL statements built from interpolated strings"
    end

    MSG = "SQL statement built from interpolated string can lead to SQL injection"

    SQL_PATTERN = /\bSELECT\s.+?\sFROM\b|\bINSERT\s+INTO\b|\bUPDATE\s+\S+\s+SET\b|\bDELETE\s+FROM\b/im

    def test(source, node : Crystal::StringInterpolation)
      return if static_literal?(node)
      return unless sql_like?(node)

      issue_for(node, MSG)
    end

    private def sql_like?(node)
      node.expressions
        .select(Crystal::StringLiteral)
        .join(' ', &.value)
        .matches?(SQL_PATTERN)
    end
  end
end
