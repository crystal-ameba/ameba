require "../../../spec_helper"

private def it_detects_empty_expression(code, *, file = __FILE__, line = __LINE__)
  it "detects empty expression #{code.inspect}", file, line do
    source = Ameba::Source.new code
    rule = Ameba::Rule::Lint::EmptyExpression.new
    rule.catch(source).should_not be_valid, file: file, line: line
  end
end

module Ameba::Rule::Lint
  describe EmptyExpression do
    subject = EmptyExpression.new

    it "passes if there is no empty expression" do
      expect_no_issues subject, <<-CRYSTAL
        def method()
        end

        method()
        method(1, 2, 3)
        method(nil)

        a = nil
        a = ""
        a = 0

        nil
        :any.nil?

        begin "" end
        [nil] << nil
        CRYSTAL
    end

    it_detects_empty_expression %(())
    it_detects_empty_expression %(((())))
    it_detects_empty_expression %(a = ())
    it_detects_empty_expression %((();()))
    it_detects_empty_expression %(if (); end)

    it_detects_empty_expression <<-CRYSTAL
      if foo
        1
      elsif ()
        2
      end
      CRYSTAL

    it_detects_empty_expression <<-CRYSTAL
      case foo
      when :foo then ()
      end
      CRYSTAL

    it_detects_empty_expression <<-CRYSTAL
      case foo
      when :foo then 1
      else
        ()
      end
      CRYSTAL

    it_detects_empty_expression <<-CRYSTAL
      case foo
      when () then 1
      end
      CRYSTAL

    it_detects_empty_expression <<-CRYSTAL
      def method
        a = 1
        ()
      end
      CRYSTAL

    it_detects_empty_expression <<-CRYSTAL
      def method
      rescue
        ()
      end
      CRYSTAL

    it_detects_empty_expression <<-CRYSTAL
      def method
        begin
        end
      end
      CRYSTAL

    it_detects_empty_expression <<-CRYSTAL
      begin; end
      CRYSTAL

    it_detects_empty_expression <<-CRYSTAL
      begin
        ()
      end
      CRYSTAL

    it "does not report empty expression in macro" do
      expect_no_issues subject, <<-CRYSTAL
        module MyModule
          macro conditional_error_for_inline_callbacks
            \\{% raise "" %}
          end

          macro before_save(x = nil)
          end
        end
        CRYSTAL
    end
  end
end
