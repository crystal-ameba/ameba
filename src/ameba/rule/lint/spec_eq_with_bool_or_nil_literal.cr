module Ameba::Rule::Lint
  # Reports `eq(true|false|nil)` expectations in specs.
  #
  # This is considered bad:
  #
  # ```
  # it "works" do
  #   foo.is_a?(String).should eq true
  #   foo.is_a?(Int32).should eq false
  #   foo.as?(Symbol).should eq nil
  # end
  # ```
  #
  # And it should be written as the following:
  #
  # ```
  # it "works" do
  #   foo.is_a?(String).should be_true
  #   foo.is_a?(Int32).should be_false
  #   foo.as?(Symbol).should be_nil
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/SpecEqWithBoolOrNilLiteral:
  #   Enabled: true
  # ```
  class SpecEqWithBoolOrNilLiteral < Base
    include AST::Util

    properties do
      since_version "1.7.0"
      description "Reports `eq(true|false|nil)` expectations in specs"
    end

    MSG = "Use `%s` instead of `%s` expectation"

    def test(source)
      return super if source.spec?
    end

    def test(source, node : Crystal::Call)
      return unless node.name.in?("should", "should_not") && node.args.size == 1
      return if has_block?(node)

      return unless (matcher = node.args.first).is_a?(Crystal::Call)
      return unless matcher.name == "eq" && matcher.args.size == 1
      return if has_block?(matcher)

      replacement =
        case arg = matcher.args.first
        when Crystal::BoolLiteral then arg.value ? "be_true" : "be_false"
        when Crystal::NilLiteral  then "be_nil"
        end
      return unless replacement

      issue_for matcher, MSG % {replacement, matcher.to_s} do |corrector|
        corrector.replace(matcher, replacement)
      end
    end
  end
end
