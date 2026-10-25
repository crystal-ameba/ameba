# Extensions to `Crystal::Arg`
module Ameba::Ext::Arg
  # Location of the argument name, if it differs from the argument location,
  # i.e. `bar` in `foo bar`, `"foo" bar` or `@bar`.
  #
  # NOTE: It's not set by `Crystal::Parser`, see `AST::ArgNameLocationVisitor`.
  property name_location : Crystal::Location?
end

class Crystal::Arg
  include Ameba::Ext::Arg
end
