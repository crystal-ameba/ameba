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
    properties do
      since_version "1.7.0"
      description "Disallows trailing `rescue` with a path"
    end

    MSG = "Use a block variant of `rescue` to filter by the exception type"

    def test(source, node : Crystal::ExceptionHandler)
      return unless node.suffix &&
                    (rescues = node.rescues) &&
                    (resc = rescues.first?) &&
                    resc.body.is_a?(Crystal::Path)

      issue_for resc.body, MSG, prefer_name_location: true
    end
  end
end
