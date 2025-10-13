require "../base"

module Ameba::Rule::Performance
  # A general base class for performance rules.
  abstract class Base < Ameba::Rule::Base
    def catch(source : Source, context : SemanticContext? = nil)
      source.spec? ? source : super
    end
  end
end
