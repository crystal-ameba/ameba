require "../../../spec_helper"

module Ameba::Rule::Layout
  subject = TrailingWhitespace.new

  describe TrailingWhitespace do
    it "passes if all lines do not have trailing whitespace" do
      expect_no_issues subject, "no-whitespace"
    end

    it "fails if there is a line with trailing whitespace" do
      source = expect_issue subject,
        "whitespace at the end  \n" \
        "                   # ^^ error: Trailing whitespace detected"

      expect_correction source, "whitespace at the end"
    end

    {% if compare_versions(Crystal::VERSION, "1.15.0") >= 0 %}
      it "fails if there is a line with trailing whitespace in an ECR file" do
        source = expect_issue subject,
          "whitespace at the end  \n" \
          "                   # ^^ error: Trailing whitespace detected",
          path: "source.ecr"

        expect_correction source, "whitespace at the end"
      end
    {% end %}
  end
end
