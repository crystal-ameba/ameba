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
  # Interpolations are not reported when every dynamic part is
  # converted to a number (`to_i`, `to_f`, ...).
  #
  # Every issue carries a confidence based on the interpolated expression:
  # `High` when it reads external input directly (`env.params`, `ARGV`, ...),
  # `Medium` for a variable, `Low` for other expressions. Issues below
  # `MinConfidence` are not reported.
  #
  # Reference: [CWE-89](https://cwe.mitre.org/data/definitions/89.html)
  #
  # YAML configuration example:
  #
  # ```
  # Security/SqlInjection:
  #   Enabled: true
  #   MinConfidence: Low
  # ```
  class SqlInjection < Base
    include AST::Util
    include EvidenceClassifier

    properties do
      since_version "1.7.0"
      description "Disallows SQL statements built from interpolated strings"
      min_confidence "Low"
    end

    MSG = "SQL statement built from interpolated string can lead to SQL injection"

    SQL_PATTERN = /\bSELECT\s.+?\sFROM\b|\bINSERT\s+INTO\b|\bUPDATE\s+\S+\s+SET\b|\bDELETE\s+FROM\b/im

    def test(source, node : Crystal::StringInterpolation)
      return unless sql_like?(node)

      parts = dynamic_parts(node)
      return if parts.empty?
      return if confidence_for(parts) < Confidence.parse(min_confidence)

      issue_for(node, MSG)
    end

    private def sql_like?(node)
      node.expressions
        .select(Crystal::StringLiteral)
        .join(' ', &.value)
        .matches?(SQL_PATTERN)
    end

    private def dynamic_parts(node)
      node.expressions.reject do |exp|
        static_literal?(exp) || safe_cast?(exp)
      end
    end
  end
end
