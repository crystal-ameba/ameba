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
  # YAML configuration example:
  #
  # ```
  # Security/CommandInjection:
  #   Enabled: true
  #   CommandCallNames:
  #     - system
  # ```
  class CommandInjection < Base
    include AST::Util

    properties do
      since_version "1.7.0"
      description "Disallows shell commands built from interpolated strings"
      command_call_names %w[system]
    end

    MSG = "Shell command built from interpolated string can lead to command injection"

    BACKTICK_CALL_NAME = "`"

    def test(source, node : Crystal::Call)
      return unless command_call?(node)
      return unless node.args.any? { |arg| dynamic_interpolation?(arg) }

      issue_for(node, MSG)
    end

    private def command_call?(node)
      node.name == BACKTICK_CALL_NAME ||
        (node.name.in?(command_call_names) && node.obj.nil?)
    end

    private def dynamic_interpolation?(node)
      node.is_a?(Crystal::StringInterpolation) && !static_literal?(node)
    end
  end
end
