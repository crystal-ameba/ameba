module Ameba::Rule::Style
  # A rule that disallows redundant return expressions.
  #
  # For example, this is considered invalid:
  #
  # ```
  # def foo
  #   return :bar
  # end
  # ```
  #
  # ```
  # def bar(arg)
  #   case arg
  #   when .nil?
  #     return "nil"
  #   when .blank?
  #     return "blank"
  #   else
  #     return "empty"
  #   end
  # end
  # ```
  #
  # And has to be written as the following:
  #
  # ```
  # def foo
  #   :bar
  # end
  # ```
  #
  # ```
  # def bar(arg)
  #   case arg
  #   when .nil?
  #     "nil"
  #   when .blank?
  #     "blank"
  #   else
  #     "empty"
  #   end
  # end
  # ```
  #
  # ### Configuration params
  #
  # 1. *allow_multi_return*, default: true
  #
  # Allows end-user to configure whether to report or not the return statements
  # which return tuple literals i.e.
  #
  # ```
  # def method(a, b)
  #   return a, b
  # end
  # ```
  #
  # If this param equals to `false`, the method above has to be written as:
  #
  # ```
  # def method(a, b)
  #   {a, b}
  # end
  # ```
  #
  # 2. *allow_empty_return*, default: true
  #
  # Allows end-user to configure whether to report or not the return statements
  # without arguments. Sometimes such returns are used to return the `nil` value explicitly.
  #
  # ```
  # def method
  #   @foo = :empty
  #   return
  # end
  # ```
  #
  # If this param equals to `false`, the method above has to be written as:
  #
  # ```
  # def method
  #   @foo = :empty
  #   nil
  # end
  # ```
  #
  # ### YAML config example
  #
  # ```
  # Style/RedundantReturn:
  #   Enabled: true
  #   AllowMutliReturn: true
  #   AllowEmptyReturn: true
  # ```
  struct RedundantReturn < Base
    properties do
      description "Reports redundant return expressions"
      allow_multi_return true
      allow_empty_return true
    end

    MSG = "Redundant `return` detected"

    @source : Source?

    def test(source)
      AST::NodeVisitor.new self, source
    end

    def test(source, node : Crystal::Def)
      @source = source
      check_node(node.body)
    end

    private def check_node(node)
      case node
      when Crystal::Return              then check_return node
      when Crystal::Expressions         then check_expressions node
      when Crystal::If, Crystal::Unless then check_condition node
      when Crystal::Case                then check_case node
      when Crystal::ExceptionHandler    then check_exception_handler node
      end
    end

    private def check_return(node)
      return if allow_multi_return && node.exp.is_a?(Crystal::TupleLiteral)
      return if allow_empty_return && (node.exp.nil? || node.exp.not_nil!.nop?)

      @source.try &.add_issue self, node, MSG
    end

    private def check_expressions(node)
      check_node node.expressions.last?
    end

    private def check_condition(node)
      return if node.else.nil? || node.else.nop?

      check_node(node.then)
      check_node(node.else)
    end

    private def check_case(node)
      node.whens.each { |n| check_node n.body }
      check_node(node.else)
    end

    private def check_exception_handler(node)
      check_node node.body
      check_node node.else
      node.rescues.try &.each { |n| check_node n.body }
    end
  end
end
