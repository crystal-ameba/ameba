require "compiler/crystal/formatter"

module Ameba::Rule
  # A rule that verifies syntax formatting according to
  # Crystal's build-in formatter.
  #
  # YAML configuration example:
  #
  # ```
  # Formatting:
  #   Enabled: true
  #   FailIfError: true
  # ```
  #
  struct Formatting < Base
    properties do
      description = "Reports not formatted sources"
      fail_if_error = true
    end

    MSG     = "Use built-in formatter to format this source"
    MSG_ERR = "Source file can't be formatted: '%s'"

    def test(source)
      result = Crystal.format(source.code, filename: source.path)
      return if result == source.code

      source.error self, 1, 1, MSG
    rescue e
      if fail_if_error
        source.error self, 1, 1, MSG_ERR % e.message
      end
    end
  end
end
