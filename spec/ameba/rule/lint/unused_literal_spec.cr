require "../../../spec_helper"

module Ameba::Rule::Lint
  subject = UnusedLiteral.new

  describe UnusedLiteral do
    it "passes if literals are used" do
      expect_no_issues subject, <<-CRYSTAL
        a = 1 == "1"
        b = begin
          2 == "3"
        end

        if c == b
          puts "meow"
        end

        def test
          1 == 2
        end
        CRYSTAL
    end

    it "fails if a literal is not used" do
      expect_issue subject, <<-CRYSTAL
          :hello
        # ^^^^^^ error: Literal value is not used

          "world"
        # ^^^^^^^ error: Literal value is not used

          { my: :name }
        # ^^^^^^^^^^^^^ error: Literal value is not used

          [
        # ^ error: Literal value is not used
            "is",
            :a
          ]

          1234
        # ^^^^ error: Literal value is not used
        CRYSTAL
    end
  end
end
