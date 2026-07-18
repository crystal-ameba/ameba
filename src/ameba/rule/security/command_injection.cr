require "./base"

module Ameba::Rule::Security
  # A rule that disallows shell commands built from interpolated strings.
  #
  # Interpolating a value into a shell command makes it possible for
  # an attacker to execute arbitrary commands if the value is not trusted.
  #
  # For example, these are considered insecure:
  #
  # ```
  # system("ls -l #{path}")
  # `cat #{file}`
  # ```
  #
  # And should be written by passing arguments separately, so they
  # never go through the shell:
  #
  # ```
  # Process.run("ls", ["-l", path])
  # File.read(file)
  # ```
  #
  # Interpolations are not reported when every dynamic part is escaped
  # with `Process.quote` or converted to a number (`to_i`, `to_f`, ...).
  #
  # Every issue carries a confidence based on the interpolated expression:
  # `High` when it reads external input directly (`env.params`, `ARGV`, ...),
  # `Medium` for a variable, `Low` for other expressions. Issues below
  # `MinConfidence` are not reported.
  #
  # Reference: [CWE-78](https://cwe.mitre.org/data/definitions/78.html)
  #
  # YAML configuration example:
  #
  # ```
  # Security/CommandInjection:
  #   Enabled: true
  #   CommandCallNames:
  #     - system
  #   MinConfidence: Low
  # ```
  class CommandInjection < Base
    include AST::Util
    include EvidenceClassifier

    properties do
      since_version "1.7.0"
      description "Disallows shell commands built from interpolated strings"
      command_call_names %w[system]
      min_confidence "Low"
    end

    MSG = "Shell command built from interpolated string can lead to command injection"

    BACKTICK_CALL_NAME = "`"

    def test(source, node : Crystal::Call)
      return unless command_call?(node)

      parts = node.args
        .select(Crystal::StringInterpolation)
        .flat_map { |arg| dynamic_parts(arg) }
      return if parts.empty?
      return if confidence_for(parts) < Confidence.parse(min_confidence)

      issue_for(node, MSG)
    end

    private def command_call?(node)
      node.name == BACKTICK_CALL_NAME ||
        (node.name.in?(command_call_names) && node.obj.nil?)
    end

    private def dynamic_parts(node)
      node.expressions.reject do |exp|
        static_literal?(exp) || safe_cast?(exp) || shell_quoted?(exp)
      end
    end

    private def shell_quoted?(node)
      node.is_a?(Crystal::Call) &&
        node.name == "quote" &&
        (obj = node.obj).is_a?(Crystal::Path) &&
        obj.names.last == "Process"
    end
  end
end
