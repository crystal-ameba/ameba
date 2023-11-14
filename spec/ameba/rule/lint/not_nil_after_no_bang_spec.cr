require "../../../spec_helper"

module Ameba::Rule::Lint
  subject = NotNilAfterNoBang.new

  describe NotNilAfterNoBang do
    it "passes for valid cases" do
      expect_no_issues subject, <<-CRYSTAL
        (1..3).index(1).not_nil!(:foo)
        (1..3).rindex(1).not_nil!(:foo)
        (1..3).index { |i| i > 2 }.not_nil!(:foo)
        (1..3).rindex { |i| i > 2 }.not_nil!(:foo)
        (1..3).find { |i| i > 2 }.not_nil!(:foo)
        /(.)(.)(.)/.match("abc", &.itself).not_nil!
        CRYSTAL
    end

    it "reports if there is an `index` call followed by `not_nil!`" do
      source = expect_issue subject, <<-CRYSTAL
        (1..3).index(1).not_nil!
             # ^^^^^^^^^^^^^^^^^ error: Use `index! {...}` instead of `index {...}.not_nil!`
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        (1..3).index!(1)
        CRYSTAL
    end

    it "reports if there is an `rindex` call followed by `not_nil!`" do
      source = expect_issue subject, <<-CRYSTAL
        (1..3).rindex(1).not_nil!
             # ^^^^^^^^^^^^^^^^^^ error: Use `rindex! {...}` instead of `rindex {...}.not_nil!`
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        (1..3).rindex!(1)
        CRYSTAL
    end

    it "reports if there is an `match` call followed by `not_nil!`" do
      source = expect_issue subject, <<-CRYSTAL
        /(.)(.)(.)/.match("abc").not_nil![2]
                  # ^^^^^^^^^^^^^^^^^^^^^ error: Use `match! {...}` instead of `match {...}.not_nil!`
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        /(.)(.)(.)/.match!("abc")[2]
        CRYSTAL
    end

    it "reports if there is an `index` call with block followed by `not_nil!`" do
      source = expect_issue subject, <<-CRYSTAL
        (1..3).index { |i| i > 2 }.not_nil!
             # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Use `index! {...}` instead of `index {...}.not_nil!`
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        (1..3).index! { |i| i > 2 }
        CRYSTAL
    end

    it "reports if there is an `rindex` call with block followed by `not_nil!`" do
      source = expect_issue subject, <<-CRYSTAL
        (1..3).rindex { |i| i > 2 }.not_nil!
             # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Use `rindex! {...}` instead of `rindex {...}.not_nil!`
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        (1..3).rindex! { |i| i > 2 }
        CRYSTAL
    end

    it "reports if there is a `find` call with block followed by `not_nil!`" do
      source = expect_issue subject, <<-CRYSTAL
        (1..3).find { |i| i > 2 }.not_nil!
             # ^^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Use `find! {...}` instead of `find {...}.not_nil!`
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        (1..3).find! { |i| i > 2 }
        CRYSTAL
    end

    it "passes if there is a `find` call without block followed by `not_nil!`" do
      expect_no_issues subject, <<-CRYSTAL
        (1..3).find(1).not_nil!
        CRYSTAL
    end

    context "macro" do
      it "doesn't report in macro scope" do
        expect_no_issues subject, <<-CRYSTAL
          {{ [1, 2, 3].index(1).not_nil! }}
          CRYSTAL
      end
    end
  end
end
