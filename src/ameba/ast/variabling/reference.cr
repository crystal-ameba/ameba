require "./variable"

module Ameba::AST
  # Represents a reference to the variable.
  # It behaves like a variable is used to distinguish the
  # variable from its reference.
  class Reference < Variable
    property? explicit = true

    # Whether the address of the variable is taken by this reference
    # (i.e. `pointerof(x)`), which allows reading (and writing) the
    # variable through the pointer.
    property? address_taken = false
  end
end
