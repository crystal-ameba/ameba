module Ameba::Rule::Lint
  # A rule that reports when `Signal::INT/HUP/TERM.trap` is used,
  # which should be replaced with `Process.on_terminate` instead -
  # a more portable alternative.
  #
  # For example, this is considered invalid:
  #
  # ```
  # Signal::INT.trap do
  #   shutdown
  # end
  # ```
  #
  # And it should be written as this:
  #
  # ```
  # Process.on_terminate do
  #   shutdown
  # end
  # ```
  #
  # NOTE: The issues are not autocorrected, since `Process.on_terminate`
  # sets a single handler for all of the INT, HUP and TERM signals (so the
  # subsequent calls replace the previous handler), and yields
  # a `Process::ExitReason` instead of a `Signal`.
  #
  # YAML configuration example:
  #
  # ```
  # Lint/SignalTrap:
  #   Enabled: true
  # ```
  class SignalTrap < Base
    include AST::Util

    properties do
      since_version "1.7.0"
      description "Disallows `Signal::INT/HUP/TERM.trap` in favor of `Process.on_terminate`"
    end

    MSG = "Use `Process.on_terminate` instead of `%s.trap`"

    def test(source, node : Crystal::Call)
      return unless (obj = node.obj).is_a?(Crystal::Path)
      return unless path_named?(obj, "Signal::INT", "Signal::HUP", "Signal::TERM")
      return unless node.name == "trap"

      if name_end_location = name_end_location(node)
        issue_for(node.location, name_end_location, MSG % obj)
      else
        issue_for(node, MSG % obj)
      end
    end
  end
end
