require "../../../spec_helper"

module Ameba::Rule::Lint
  describe AmbiguousAssignment do
    subject = AmbiguousAssignment.new

    context "when using `-`" do
      it "registers an offense with `x`" do
        source = Source.new("x =- y", "source.cr")
        subject.catch(source).should_not be_valid
        source.issues.size.should eq 1

        issue = source.issues.first
        issue.message.should eq "Suspicious assignment detected. Did you mean `-=`?"
        issue.location.to_s.should eq "source.cr:1:3"
        issue.end_location.to_s.should eq "source.cr:1:4"
      end

      it "registers an offense with `@x`" do
        source = Source.new("@x =- y", "source.cr")
        subject.catch(source).should_not be_valid
        source.issues.size.should eq 1

        issue = source.issues.first
        issue.message.should eq "Suspicious assignment detected. Did you mean `-=`?"
        issue.location.to_s.should eq "source.cr:1:4"
        issue.end_location.to_s.should eq "source.cr:1:5"
      end

      it "registers an offense with `@@x`" do
        source = Source.new("@@x =- y", "source.cr")
        subject.catch(source).should_not be_valid
        source.issues.size.should eq 1

        issue = source.issues.first
        issue.message.should eq "Suspicious assignment detected. Did you mean `-=`?"
        issue.location.to_s.should eq "source.cr:1:5"
        issue.end_location.to_s.should eq "source.cr:1:6"
      end

      it "registers an offense with `X`" do
        source = Source.new("X =- y", "source.cr")
        subject.catch(source).should_not be_valid
        source.issues.size.should eq 1

        issue = source.issues.first
        issue.message.should eq "Suspicious assignment detected. Did you mean `-=`?"
        issue.location.to_s.should eq "source.cr:1:3"
        issue.end_location.to_s.should eq "source.cr:1:4"
      end

      it "does not register an offense when no mistype assignments" do
        subject.catch(Source.new(<<-CRYSTAL)).should be_valid
          x = 1
          x -= y
          x = -y
        CRYSTAL
      end
    end

    context "when using `+`" do
      it "registers an offense with `x`" do
        source = Source.new("x =+ y", "source.cr")
        subject.catch(source).should_not be_valid
        source.issues.size.should eq 1

        issue = source.issues.first
        issue.message.should eq "Suspicious assignment detected. Did you mean `+=`?"
        issue.location.to_s.should eq "source.cr:1:3"
        issue.end_location.to_s.should eq "source.cr:1:4"
      end

      it "registers an offense with `@x`" do
        source = Source.new("@x =+ y", "source.cr")
        subject.catch(source).should_not be_valid
        source.issues.size.should eq 1

        issue = source.issues.first
        issue.message.should eq "Suspicious assignment detected. Did you mean `+=`?"
        issue.location.to_s.should eq "source.cr:1:4"
        issue.end_location.to_s.should eq "source.cr:1:5"
      end

      it "registers an offense with `@@x`" do
        source = Source.new("@@x =+ y", "source.cr")
        subject.catch(source).should_not be_valid
        source.issues.size.should eq 1

        issue = source.issues.first
        issue.message.should eq "Suspicious assignment detected. Did you mean `+=`?"
        issue.location.to_s.should eq "source.cr:1:5"
        issue.end_location.to_s.should eq "source.cr:1:6"
      end

      it "registers an offense with `X`" do
        source = Source.new("X =+ y", "source.cr")
        subject.catch(source).should_not be_valid
        source.issues.size.should eq 1

        issue = source.issues.first
        issue.message.should eq "Suspicious assignment detected. Did you mean `+=`?"
        issue.location.to_s.should eq "source.cr:1:3"
        issue.end_location.to_s.should eq "source.cr:1:4"
      end

      it "does not register an offense when no mistype assignments" do
        subject.catch(Source.new(<<-CRYSTAL)).should be_valid
          x = 1
          x += y
          x = +y
        CRYSTAL
      end
    end

    context "when using `!`" do
      it "registers an offense with `x`" do
        source = Source.new("x =! y", "source.cr")
        subject.catch(source).should_not be_valid
        source.issues.size.should eq 1

        issue = source.issues.first
        issue.message.should eq "Suspicious assignment detected. Did you mean `!=`?"
        issue.location.to_s.should eq "source.cr:1:3"
        issue.end_location.to_s.should eq "source.cr:1:4"
      end

      it "registers an offense with `@x`" do
        source = Source.new("@x =! y", "source.cr")
        subject.catch(source).should_not be_valid
        source.issues.size.should eq 1

        issue = source.issues.first
        issue.message.should eq "Suspicious assignment detected. Did you mean `!=`?"
        issue.location.to_s.should eq "source.cr:1:4"
        issue.end_location.to_s.should eq "source.cr:1:5"
      end

      it "registers an offense with `@@x`" do
        source = Source.new("@@x =! y", "source.cr")
        subject.catch(source).should_not be_valid
        source.issues.size.should eq 1

        issue = source.issues.first
        issue.message.should eq "Suspicious assignment detected. Did you mean `!=`?"
        issue.location.to_s.should eq "source.cr:1:5"
        issue.end_location.to_s.should eq "source.cr:1:6"
      end

      it "registers an offense with `X`" do
        source = Source.new("X =! y", "source.cr")
        subject.catch(source).should_not be_valid
        source.issues.size.should eq 1

        issue = source.issues.first
        issue.message.should eq "Suspicious assignment detected. Did you mean `!=`?"
        issue.location.to_s.should eq "source.cr:1:3"
        issue.end_location.to_s.should eq "source.cr:1:4"
      end

      it "does not register an offense when no mistype assignments" do
        subject.catch(Source.new(<<-CRYSTAL)).should be_valid
          x = false
          x != y
          x = !y
        CRYSTAL
      end
    end
  end
end
