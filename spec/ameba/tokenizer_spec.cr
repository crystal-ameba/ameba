require "../spec_helper"

private def it_tokenizes(str, expected)
  it "tokenizes #{str}" do
    ([] of Symbol).tap do |token_types|
      Ameba::Tokenizer.new(Ameba::Source.new str).run do |token|
        token_types << token.type
      end.should be_true
    end.should eq expected
  end
end

module Ameba
  describe Tokenizer do
    describe "#run" do
      it_tokenizes %("string"), %i(STRING)
      it_tokenizes %(100), %i(NUMBER)
      it_tokenizes %('a'), %i(CHAR)
      it_tokenizes %([]), %i([])
      it_tokenizes %([] of String), %i([] SPACE IDENT SPACE CONST)
      it_tokenizes %q("str #{3}"), %i(STRING NUMBER)

      it_tokenizes %(%w(1 2)),
        %i(STRING_ARRAY_START STRING STRING STRING_ARRAY_END)

      it_tokenizes %(%i(one two)),
        %i(SYMBOL_ARRAY_START STRING STRING STRING_ARRAY_END)

      it_tokenizes %(
        class A
          def method
            puts "hello"
          end
        end
      ), [
        :NEWLINE, :SPACE, :IDENT, :SPACE, :CONST, :NEWLINE, :SPACE, :IDENT,
        :SPACE, :IDENT, :NEWLINE, :SPACE, :IDENT, :SPACE, :STRING, :NEWLINE,
        :SPACE, :IDENT, :NEWLINE, :SPACE, :IDENT, :NEWLINE, :SPACE,
      ]
    end
  end
end
