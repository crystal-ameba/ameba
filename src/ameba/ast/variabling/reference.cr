require "./variable"

module Ameba::AST
  # Represents a reference to the variable.
  # It behaves like a variable is used to distinguish the
  # variable from its reference.
  class Reference < Variable
    property? explicit = true
  end
end
