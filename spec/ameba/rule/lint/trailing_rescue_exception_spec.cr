require "../../../spec_helper"

module Ameba::Rule::Lint
  describe TrailingRescueException do
    subject = TrailingRescueException.new

    it "passes for trailing rescue with literal values" do
      expect_no_issues subject, <<-CRYSTAL
        puts "foo" rescue "bar"
        puts :foo rescue 42
        CRYSTAL
    end

    it "passes for trailing rescue with class initialization" do
      expect_no_issues subject, <<-CRYSTAL
        puts "foo" rescue MyClass.new
        CRYSTAL
    end

    it "fails if trailing rescue has exception name" do
      source = expect_issue subject, <<-CRYSTAL
        def foo
          puts "hello" rescue MyException
                            # ^^^^^^^^^^^ error: Use a block variant of `rescue` to filter by the exception type
        end
        CRYSTAL

      # https://github.com/crystal-lang/crystal/pull/17365
      {% if compare_versions(Crystal::VERSION, "1.22.0-dev") >= 0 %}
        expect_correction source, <<-CRYSTAL
          def foo
            begin
              puts "hello"
            rescue MyException
            end
          end
          CRYSTAL
      {% else %}
        expect_no_corrections source
      {% end %}
    end
  end
end
