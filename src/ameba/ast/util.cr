module Ameba::AST::Util
  def literal?(node)
    node.try &.class.name.ends_with? "Literal"
  end

  def string_literal?(node)
    node.is_a? Crystal::StringLiteral
  end
end
