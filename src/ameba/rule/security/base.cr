require "../base"

module Ameba::Rule::Security
  # A general base class for security rules.
  abstract class Base < Ameba::Rule::Base
    def catch(source : Source)
      source.spec? ? source : super
    end
  end
end
