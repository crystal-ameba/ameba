require "../../../spec_helper"

module Ameba::Rule::Lint
  subject = DebugCalls.new

  describe DebugCalls do
    it "fails if there is a debug call" do
      subject.method_names.each do |name|
        source = expect_issue subject, <<-CRYSTAL, name: name
          a = 2
          %{name} a
          # ^{name} error: Possibly forgotten debug-related `%{name}` call detected
          a = a + 1
          CRYSTAL

        expect_no_corrections source
      end
    end

    it "passes if there is no debug call" do
      subject.method_names.each do |name|
        expect_no_issues subject, <<-CRYSTAL
          class A
            def #{name}
            end
          end
          A.new.#{name}
          CRYSTAL
      end
    end
  end
end
