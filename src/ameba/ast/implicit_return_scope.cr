module Ameba::AST
  class ImplicitReturnScope
    # When greater than zero, indicates the current node's return value is used
    property stack : Int32 = 0

    property? in_macro : Bool = false

    def node_is_used? : Bool
      @stack.positive?
    end
  end
end
