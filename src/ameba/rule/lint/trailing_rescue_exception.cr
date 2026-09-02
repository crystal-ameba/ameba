module Ameba::Rule::Lint
  # A rule that prohibits the misconception about how trailing `rescue` statements work,
  # preventing Paths (exception class names or otherwise) from being used as the
  # trailing value. The value after the trailing `rescue` statement is the value
  # to use if an exception occurs, not the exception class to rescue from.
  #
  # For example, this is considered invalid - if an exception occurs,
  # `response` will be assigned with the value of `IO::Error` instead of `nil`:
  #
  # ```
  # response = HTTP::Client.get("http://www.example.com") rescue IO::Error
  # ```
  #
  # And should instead be written as this in order to capture only `IO::Error` exceptions:
  #
  # ```
  # response = begin
  #   HTTP::Client.get("http://www.example.com")
  # rescue IO::Error
  #   "default value"
  # end
  # ```
  #
  # Or to rescue all exceptions (instead of just `IO::Error`):
  #
  # ```
  # response = HTTP::Client.get("http://www.example.com") rescue "default value"
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/TrailingRescueException:
  #   Enabled: true
  # ```
  class TrailingRescueException < Base
    include AST::Util

    properties do
      since_version "1.7.0"
      description "Disallows trailing `rescue` with a path"
    end

    MSG = "Use a block variant of `rescue` to filter by the exception type"

    def test(source, node : Crystal::ExceptionHandler)
      return unless node.suffix &&
                    (rescue_node = node.rescues.try(&.first?)) &&
                    (rescue_body = rescue_node.body).is_a?(Crystal::Path)

      issue_for(rescue_body, MSG, prefer_name_location: true) do |corrector|
        next unless node_source = node_source(node.body, source.lines)

        corrector.replace node, <<-CRYSTAL
          begin
            #{node_source}
          rescue #{rescue_body}
          end
          CRYSTAL
      end
    end
  end
end
