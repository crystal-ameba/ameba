require "../spec_helper"

module Ameba
  private def it_tokenizes(str, expected, *, file = __FILE__, line = __LINE__)
    it "tokenizes #{str}", file, line do
      %w[].tap do |token_types|
        Tokenizer.new(Source.new str, normalize: false)
          .run { |token| token_types << token.type.to_s }
          .should be_true
      end.should eq(expected), file: file, line: line
    end
  end

  describe Tokenizer do
    describe "#run" do
      it_tokenizes %("string"), %w(DELIMITER_START STRING DELIMITER_END EOF)
      it_tokenizes %(100), %w(NUMBER EOF)
      it_tokenizes %('a'), %w(CHAR EOF)
      it_tokenizes %([]), %w([] EOF)
      it_tokenizes %([] of String), %w([] SPACE IDENT SPACE CONST EOF)
      it_tokenizes %q("str #{3}"), %w(
        DELIMITER_START STRING INTERPOLATION_START NUMBER } DELIMITER_END EOF
      )

      it_tokenizes %(%w[1 2]),
        %w[STRING_ARRAY_START STRING STRING STRING_ARRAY_END EOF]

      it_tokenizes %(%i[one two]),
        %w[SYMBOL_ARRAY_START STRING STRING STRING_ARRAY_END EOF]

      it_tokenizes %(
        class A
          def method
            puts "hello"
          end
        end
      ), %w[
        NEWLINE SPACE IDENT SPACE CONST NEWLINE SPACE IDENT SPACE IDENT
        NEWLINE SPACE IDENT SPACE DELIMITER_START STRING DELIMITER_END
        NEWLINE SPACE IDENT NEWLINE SPACE IDENT NEWLINE SPACE EOF
      ]
    end
  end
end
