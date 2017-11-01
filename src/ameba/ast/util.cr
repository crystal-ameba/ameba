module Ameba::AST::Util
  def literal?(node)
    node.try &.class.name.ends_with? "Literal"
  end
end
