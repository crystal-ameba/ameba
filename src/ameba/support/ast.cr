{% if Crystal::VERSION == "0.24.2" %}
  # workaround for https://github.com/crystal-lang/crystal/pull/6032
  module Crystal
    class Case < ASTNode
      def accept_children(visitor)
        @cond.try &.accept visitor
        @whens.each &.accept visitor
        @else.try &.accept visitor
      end
    end
  end
{% end %}
