require "../../../spec_helper"

module Ameba::Rule::Lint
  describe DebugCalls do
    subject = DebugCalls.new

    it "fails if there is a debug call" do
      subject.method_names.each do |name|
        expect_issue subject, <<-CRYSTAL, name: name
          a = 2
          %{name} a
          # ^{name} error: Possibly forgotten debug-related `%{name}` call detected
          a = a + 1
          CRYSTAL
      end
    end

    it "autocorrects by removing debug calls" do
      subject.method_names.each do |name|
        expect_correction subject, <<-CRYSTAL, name: name
          a = 2
          %{name} a
          # ^{name}
          a = a + 1
          CRYSTAL
          a = 2
          a = a + 1
        CRYSTAL
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
