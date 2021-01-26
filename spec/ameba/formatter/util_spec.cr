require "../../spec_helper"

module Ameba::Formatter
  class Subject
    include Util
  end

  subject = Subject.new

  describe Util do
    describe "#deansify" do
      it "returns given string without ANSI codes" do
        str = String.build do |io|
          io << "foo".colorize.green.underline
          io << '-'
          io << "bar".colorize.red.underline
        end
        subject.deansify("foo-bar").should eq "foo-bar"
        subject.deansify(str).should eq "foo-bar"
      end
    end

    describe "#trim" do
      it "trims string longer than :max_length" do
        subject.trim(("+" * 300), 1).should eq "+"
        subject.trim(("+" * 300), 3).should eq "+++"
        subject.trim(("+" * 300), 5).should eq "+ ..."
        subject.trim(("+" * 300), 7).should eq "+++ ..."
      end

      it "leaves intact string shorter than :max_length" do
        subject.trim(("+" * 3), 100).should eq "+++"
      end

      it "allows to use custom ellipsis" do
        subject.trim(("+" * 300), 3, "…").should eq "++…"
      end
    end

    describe "#context" do
      it "returns correct pre/post context lines" do
        source = Source.new <<-EOF
          # pre:1
            # pre:2
              # pre:3
                # pre:4
                  # pre:5
          a = 1
                  # post:1
                # post:2
              # post:3
            # post:4
          # post:5
          EOF

        subject.context(source.lines, lineno: 6, context_lines: 3)
          .should eq({<<-PRE.lines, <<-POST.lines
                # pre:3
                  # pre:4
                    # pre:5
            PRE
                    # post:1
                  # post:2
                # post:3
            POST
          })
      end
    end

    describe "#affected_code" do
      it "returns nil if there is no such a line number" do
        source = Source.new %(
          a = 1
        )
        location = Crystal::Location.new("filename", 2, 1)
        subject.affected_code(source, location).should be_nil
      end

      it "returns correct line if it is found" do
        source = Source.new %(
          a = 1
        )
        location = Crystal::Location.new("filename", 1, 1)
        subject.deansify(subject.affected_code(source, location))
          .should eq "> a = 1\n  ^\n"
      end

      it "returns correct line if it is found" do
        source = Source.new <<-EOF
          # pre:1
            # pre:2
              # pre:3
                # pre:4
                  # pre:5
          a = 1
                  # post:1
                # post:2
              # post:3
            # post:4
          # post:5
          EOF

        location = Crystal::Location.new("filename", 6, 1)
        subject.deansify(subject.affected_code(source, location, context_lines: 3))
          .should eq <<-STR
            >     # pre:3
            >       # pre:4
            >         # pre:5
            > a = 1
              ^
            >         # post:1
            >       # post:2
            >     # post:3

            STR
      end
    end
  end
end
