module Ameba::Rule::Performance
  # This rule is used to identify usage of `size` calls that follow to object
  # caller names `select` and `reject`.
  #
  # For example, this is considered invalid:
  #
  # ```
  # [1, 2, 3].select { |e| e > 2 }.size
  # [1, 2, 3].reject { |e| e < 2 }.size
  # [1, 2, 3].select(&.< 2).size
  # [0, 1, 2].reject(&.zero?).size
  # ```
  #
  # And it should be written as this:
  #
  # ```
  # [1, 2, 3].count { |e| e > 2 }
  # [1, 2, 3].count { |e| e < 2 }
  # [1, 2, 3].count(&.< 2)
  # [0, 1, 2].count(&.zero?)
  # ```
  #
  struct Count < Base
    SIZE_CALL_NAME = "size"
    MSG = "Use `count {...}` instead of `%s {...}.#{SIZE_CALL_NAME}`."

    properties do
      object_call_names : Array(String) = %w(select reject)
      description "Identifies usage of `size` calls that follow to object \
                   caller names (`select`/`reject` by default)."
    end


    def test(source)
      AST::NodeVisitor.new self, source
    end

    def test(source, node : Crystal::Call)
      return unless node.name == SIZE_CALL_NAME && (obj = node.obj)

      if obj.is_a?(Crystal::Call) &&
         object_call_names.includes?(obj.name) && !obj.block.nil?

        issue_for obj, MSG % obj.name
      end
    end
  end
end
