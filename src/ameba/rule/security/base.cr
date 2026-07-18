require "../base"

module Ameba::Rule::Security
  # A general base class for security rules.
  # Spec files are not inspected: test fixtures are full of
  # placeholder secrets and command snippets.
  abstract class Base < Ameba::Rule::Base
    def test(source : Source)
      return if source.spec?

      super
    end
  end

  # How likely a security finding is a true positive,
  # based on the shape of the expression that triggered it.
  enum Confidence
    Low
    Medium
    High
  end

  # Classifies expressions by how likely they carry user-controlled input:
  #
  # - `High` - the expression reads external input directly
  #   (`env.params`, `request.headers`, `ARGV`, `STDIN.gets`, ...)
  # - `Medium` - a variable whose origin is unknown
  # - `Low` - any other expression (method calls, constants, ...)
  module EvidenceClassifier
    INPUT_CALL_NAMES  = %w[params query_params form_params body headers cookies request gets read_line]
    INPUT_CONST_NAMES = %w[ARGV STDIN]

    SAFE_CAST_NAMES = %w[to_i to_i8 to_i16 to_i32 to_i64 to_u to_u8 to_u16 to_u32 to_u64 to_f to_f32 to_f64]

    def confidence_for(nodes : Enumerable) : Confidence
      nodes.max_of { |node| confidence_for(node) }
    end

    def confidence_for(node : Crystal::ASTNode) : Confidence
      case node
      when Crystal::Call
        input_call?(node) ? Confidence::High : Confidence::Low
      when Crystal::Var, Crystal::InstanceVar, Crystal::ClassVar
        Confidence::Medium
      when Crystal::Path
        input_const?(node) ? Confidence::High : Confidence::Low
      else
        Confidence::Medium
      end
    end

    def input_call?(node : Crystal::Call) : Bool
      return true if node.name.in?(INPUT_CALL_NAMES)

      case obj = node.obj
      when Crystal::Call then input_call?(obj)
      when Crystal::Path then input_const?(obj)
      else                    false
      end
    end

    def input_const?(node : Crystal::Path) : Bool
      node.names.first.in?(INPUT_CONST_NAMES)
    end

    def safe_cast?(node : Crystal::ASTNode) : Bool
      node.is_a?(Crystal::Call) && node.name.in?(SAFE_CAST_NAMES)
    end
  end
end
