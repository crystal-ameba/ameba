require "../../../spec_helper"

module Ameba::Rule::Lint
  describe RedundantStringCoercion do
    subject = RedundantStringCoercion.new

    it "does not report if there is no redundant string coercion" do
      expect_no_issues subject, <<-'CRYSTAL'
        "Hello, #{name}"
        CRYSTAL
    end

    it "does not report if coercion is used in binary op" do
      expect_no_issues subject, <<-'CRYSTAL'
        "Hello, #{3.to_s + 's'}"
        CRYSTAL
    end

    {% for v in %w[name :symbol 42 false 't'] %}
      it "reports if there is a redundant string coercion ({{ v.id }})" do
        expect_issue subject, <<-'CRYSTAL', v: {{ v }}
          "Hello, #{%{v}.to_s}"
                  _{v} # ^^^^ error: Redundant use of `Object#to_s` in interpolation
          CRYSTAL
      end
    {% end %}

    it "reports redundant coercion in regex" do
      expect_issue subject, <<-'CRYSTAL'
        /\w #{name.to_s}/
                 # ^^^^ error: Redundant use of `Object#to_s` in interpolation
        CRYSTAL
    end

    it "doesn't report if Object#to_s is called with arguments" do
      expect_no_issues subject, <<-'CRYSTAL'
        /\w #{name.to_s(io)}/
        CRYSTAL
    end

    it "doesn't report if Object#to_s is called without receiver" do
      expect_no_issues subject, <<-'CRYSTAL'
        /\w #{to_s}/
        CRYSTAL
    end

    it "doesn't report if Object#to_s is called with named args" do
      expect_no_issues subject, <<-'CRYSTAL'
        "0x#{250.to_s(base: 16)}"
        CRYSTAL
    end
  end
end
