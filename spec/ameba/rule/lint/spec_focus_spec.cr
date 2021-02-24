require "../../../spec_helper"

module Ameba::Rule::Lint
  describe SpecFocus do
    subject = SpecFocus.new

    it "does not report if spec is not focused" do
      s = Source.new %(
        context "context" {}
        describe "describe" {}
        it "it" {}
        pending "pending" {}
      ), path: "source_spec.cr"

      subject.catch(s).should be_valid
    end

    it "reports if there is a focused context" do
      s = Source.new %(
        context "context", focus: true do
        end
      ), path: "source_spec.cr"

      subject.catch(s).should_not be_valid
    end

    it "reports if there is a focused describe block" do
      s = Source.new %(
        describe "describe", focus: true do
        end
      ), path: "source_spec.cr"

      subject.catch(s).should_not be_valid
    end

    it "reports if there is a focused it block" do
      s = Source.new %(
        it "it", focus: true do
        end
      ), path: "source_spec.cr"

      subject.catch(s).should_not be_valid
    end

    it "reports if there is a focused pending block" do
      s = Source.new %(
        pending "pending", focus: true do
        end
      ), path: "source_spec.cr"

      subject.catch(s).should_not be_valid
    end

    it "reports if there is a spec item with `focus: false`" do
      s = Source.new %(
        it "it", focus: false do
        end
      ), path: "source_spec.cr"

      subject.catch(s).should_not be_valid
    end

    it "does not report if there is non spec block with :focus" do
      s = Source.new %(
        some_method "foo", focus: true do
        end
      ), path: "source_spec.cr"

      subject.catch(s).should be_valid
    end

    it "does not report if there is a tagged item with :focus" do
      s = Source.new %(
        it "foo", tags: "focus" do
        end
      ), path: "source_spec.cr"

      subject.catch(s).should be_valid
    end

    it "does not report if there are focused spec items without blocks" do
      s = Source.new %(
        describe "foo", focus: true
        context "foo", focus: true
        it "foo", focus: true
        pending "foo", focus: true
      ), path: "source_spec.cr"

      subject.catch(s).should be_valid
    end

    it "does not report if there are focused items out of spec file" do
      s = Source.new %(
        describe "foo", focus: true {}
        context "foo", focus: true {}
        it "foo", focus: true {}
        pending "foo", focus: true {}
      )

      subject.catch(s).should be_valid
    end

    it "reports rule, pos and message" do
      s = Source.new %(
        it "foo", focus: true do
          it "bar", focus: true {}
        end
      ), path: "source_spec.cr"

      subject.catch(s).should_not be_valid

      s.issues.size.should eq(2)

      first, second = s.issues

      first.rule.should_not be_nil
      first.location.to_s.should eq "source_spec.cr:1:11"
      first.end_location.to_s.should eq ""
      first.message.should eq "Focused spec item detected"

      second.rule.should_not be_nil
      second.location.to_s.should eq "source_spec.cr:2:13"
      second.end_location.to_s.should eq ""
      second.message.should eq "Focused spec item detected"
    end
  end
end
