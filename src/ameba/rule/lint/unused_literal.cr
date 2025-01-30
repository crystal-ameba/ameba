module Ameba::Rule::Lint
  # A rule that disallows unused literal values (strings, symbols, integers, etc).
  #
  # For example, these are considered invalid:
  #
  # ```
  # 1234_f32
  #
  # "hello world"
  #
  # if check?
  #   true
  # else
  #   false
  # end
  #
  # def method
  #   if guard?
  #     false
  #   end
  #
  #   true
  # end
  # ```
  #
  # And these are considered valid:
  #
  # ```
  # a = 1234_f32
  #
  # def method
  #   if guard?
  #     false
  #   else
  #     true
  #   end
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/UnusedLiteral:
  #   Enabled: true
  # ```
  class UnusedLiteral < Base
    properties do
      since_version "1.7.0"
      description "Disallows unused literal values"
    end

    MSG = "Literal value is not used"

    def test(source : Source)
      AST::ImplicitReturnVisitor.new(self, source)
    end

    def test(source, node : Crystal::RegexLiteral, node_is_used : Bool)
      # Locations for Regex literals were added in Crystal v1.15.0
      {% if compare_versions(Crystal::VERSION, "1.15.0") >= 0 %}
        issue_for node, MSG unless node_is_used
      {% end %}
    end

    def test(
      source,
      node : Crystal::BoolLiteral | Crystal::CharLiteral | Crystal::HashLiteral |
             Crystal::ProcLiteral | Crystal::ArrayLiteral | Crystal::RangeLiteral |
             Crystal::TupleLiteral | Crystal::NumberLiteral |
             Crystal::StringLiteral | Crystal::SymbolLiteral |
             Crystal::NamedTupleLiteral | Crystal::StringInterpolation,
      node_is_used : Bool,
    )
      issue_for node, MSG unless node_is_used
    end
  end
end
