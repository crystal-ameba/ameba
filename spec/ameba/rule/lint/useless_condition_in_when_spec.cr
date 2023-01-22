require "../../../spec_helper"

module Ameba::Rule::Lint
  subject = UselessConditionInWhen.new

  describe UselessConditionInWhen do
    it "passes if there is not useless condition" do
      expect_no_issues subject, <<-CRYSTAL
        case
        when utc?
          io << " UTC"
        when local?
          Format.new(" %:z").format(self, io) if utc?
        end
        CRYSTAL
    end

    it "fails if there is useless if condition" do
      expect_issue subject, <<-CRYSTAL
        case
        when utc?
          io << " UTC" if utc?
                        # ^^^^ error: Useless condition in when detected
        end
        CRYSTAL
    end
  end
end
