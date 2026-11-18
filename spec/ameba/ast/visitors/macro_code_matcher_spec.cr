require "../../../spec_helper"

module Ameba::AST
  describe MacroCodeMatcher do
    describe "#matches?" do
      {
        "{% begin %}\n  foo\n{% end %}",
        "{% begin %}{% if bar %}# baz{% end %}foo{% end %}",
        "{% begin %}{% if bar %}# baz{% else %}qux{% end %}foo{% end %}",
        "{% begin %}\n  a = {{ bar }} / 2; b = foo / 3\n{% end %}",
        "{% begin %}{% for x in y %}# bar{% end %}foo{% end %}",
        "{% begin %}{% for x in y %}\"{% end %}foo\"{% end %}",
        "{% begin %}\n  bar /a\#{foo}b/\n{% end %}",
      }.each do |code|
        it "returns true for #{code.inspect}" do
          node = Crystal::Parser.new(code).parse
          MacroCodeMatcher.new(node, /\bfoo\b/).matches?.should be_true
        end
      end

      {
        "{% begin %}\n  # foo\n{% end %}",
        %({% begin %}\n  "foo"\n{% end %}),
        %({{ "foo".id }}),
        "{% if foo %}{% end %}",
        "{% begin %}{% if bar %}# baz{% else %}# qux{% end %}foo{% end %}",
        "{% begin %}{% for x in y %}\n{% end %}# foo{% end %}",
      }.each do |code|
        it "returns false for #{code.inspect}" do
          node = Crystal::Parser.new(code).parse
          MacroCodeMatcher.new(node, /\bfoo\b/).matches?.should be_false
        end
      end
    end
  end
end
