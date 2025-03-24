require "../../../spec_helper"

module Ameba::Rule::Lint
  describe ElseNil do
    subject = ElseNil.new

    {% for keyword in %w[if unless].map(&.id) %}
      it "does not report if `else` block of an `{{ keyword }}` has a non-nil body" do
        expect_no_issues subject, <<-CRYSTAL
          {{ keyword }} foo
            do_foo
          else
            do_bar
          end
          CRYSTAL
      end

      it "reports if there is an `else` block of an `{{ keyword }}` with a `nil` body" do
        source = expect_issue subject, <<-CRYSTAL
          {{ keyword }} foo
            do_foo
          else
            nil
          # ^^^ error: Avoid `else` blocks with `nil` as their body
          end
          CRYSTAL

        expect_correction source, <<-CRYSTAL
          {{ keyword }} foo
            do_foo
          end
          CRYSTAL
      end
    {% end %}

    it "does not report if there is an `else` block of an ternary `if` with a `nil` body" do
      expect_no_issues subject, <<-CRYSTAL
        foo ? do_foo : nil
        CRYSTAL
    end

    it "does not report if `else` block of a `case` has a non-nil body" do
      expect_no_issues subject, <<-CRYSTAL
        case foo
        when :foo
          do_foo
        else
          do_bar
        end
        CRYSTAL
    end

    it "reports if there is an `else` block of a `case` with a `nil` body" do
      source = expect_issue subject, <<-CRYSTAL
        case foo
        when :foo
          do_foo
        else
          nil
        # ^^^ error: Avoid `else` blocks with `nil` as their body
        end
        CRYSTAL

      expect_no_corrections source
    end
  end
end
