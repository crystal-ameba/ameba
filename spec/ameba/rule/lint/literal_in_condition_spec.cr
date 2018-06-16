require "../../../spec_helper"

module Ameba::Rule::Lint
  subject = LiteralInCondition.new

  describe LiteralInCondition do
    it "passes if there is not literals in conditional" do
      s = Source.new %(
        if a == 2
          :ok
        end

        :ok unless b

        case string
        when "a"
          :ok
        when "b"
          :ok
        end

        unless a.nil?
          :ok
        end
      )
      subject.catch(s).should be_valid
    end

    it "fails if there is a predicate in if conditional" do
      s = Source.new %(
        if "string"
          :ok
        end
      )
      subject.catch(s).should_not be_valid
    end

    it "fails if there is a predicate in unless conditional" do
      s = Source.new %(
        unless true
          :ok
        end
      )
      subject.catch(s).should_not be_valid
    end

    it "fails if there is a predicate in case conditional" do
      s = Source.new %(
        case [1, 2, 3]
        when :array
          :ok
        when :not_array
          :also_ok
        end
      )
      subject.catch(s).should_not be_valid
    end

    it "reports rule, pos and message" do
      s = Source.new %(
        puts "hello" if true
      ), "source.cr"
      subject.catch(s).should_not be_valid

      s.issues.size.should eq 1
      issue = s.issues.first
      issue.rule.should_not be_nil
      issue.location.to_s.should eq "source.cr:2:9"
      issue.message.should eq "Literal value found in conditional"
    end
  end
end
