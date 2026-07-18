require "../base"

module Ameba::Rule::Security
  # A general base class for security rules.
  # Spec files are not inspected: test fixtures are full of
  # placeholder secrets and command snippets.
  abstract class Base < Ameba::Rule::Base
    def test(source : Source)
      return if source.spec?

      super
    end
  end
end
