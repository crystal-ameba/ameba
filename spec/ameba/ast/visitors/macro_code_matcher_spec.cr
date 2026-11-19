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
        "{% begin %}{% if false %}\"{% end %}foo{% end %}",
        "{% begin %}{% if true %}{% else %}\"{% end %}foo{% end %}",
        "{% if false %}foo{% end %}",
        "{% begin %}{% for x in [1, 2] %}\"{% end %}foo{% end %}",
        "{% begin %}\n  bar{% if baz %}{% end %} %r{a\#{foo}}\n{% end %}",
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
        "{% begin %}{% if true %}\"{% end %}foo\"{% end %}",
        "{% begin %}{% if 1 %}# bar{% end %}foo{% end %}",
        "{% begin %}{% if :bar %}# baz{% else %}qux{% end %}foo{% end %}",
        "{% begin %}{% for x in [1] %}# bar{% end %}foo{% end %}",
        "{% begin %}{% for x in {a: 1} %}# bar{% end %}foo{% end %}",
        "{% begin %}{% for x in [1, 2, 3] %}\"{% end %}foo\"{% end %}",
        "{% begin %}{% for x in [] of Nil %}\"{% end %}# foo{% end %}",
      }.each do |code|
        it "returns false for #{code.inspect}" do
          node = Crystal::Parser.new(code).parse
          MacroCodeMatcher.new(node, /\bfoo\b/).matches?.should be_false
        end
      end
    end

    context "beyond the maximum number of lexical states" do
      branches = (0...16).join { |i| "{% if bar %}; <<-H#{i}{% end %}" }

      it "matches the following code as is" do
        node = Crystal::Parser.new("{% begin %}nil#{branches}\nfoo\n{% end %}").parse
        MacroCodeMatcher.new(node, /\bfoo\b/).matches?.should be_true

        node = Crystal::Parser.new("{% begin %}nil#{branches} # foo{% end %}").parse
        MacroCodeMatcher.new(node, /\bfoo\b/).matches?.should be_true
      end

      it "doesn't match if there's no match" do
        node = Crystal::Parser.new("{% begin %}nil#{branches}\nbar\n{% end %}").parse
        MacroCodeMatcher.new(node, /\bfoo\b/).matches?.should be_false
      end

      it "doesn't match the code following the skipped branch" do
        node = Crystal::Parser.new("{% begin %}{% if false %}#{branches}{% end %} # foo{% end %}").parse
        MacroCodeMatcher.new(node, /\bfoo\b/).matches?.should be_false
      end
    end
  end
end
