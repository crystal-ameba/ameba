require "../../spec_helper"

module Ameba::Formatter
  class Subject
    include Util
  end

  describe Util do
    subject = Subject.new

    describe "#colorize_text_styles" do
      it "underlines headings" do
        1.upto(6) do |i|
          string = "#{("#" * i)} foo"

          subject.colorize_text_styles(string)
            .should eq string.colorize.underline.to_s
        end
      end

      it "applies italic" do
        %w[* _].each do |char|
          string = "%1$s|foo|%1$s" % char

          subject.colorize_text_styles(string)
            .should eq string.colorize.italic.to_s
        end
      end

      it "applies bold" do
        %w[* _].each do |char|
          string = "%1$s|foo|%1$s" % (char * 2)

          subject.colorize_text_styles(string)
            .should eq string.colorize.bold.to_s
        end
      end

      it "applies strikethrough" do
        string = "~~foo~~"

        subject.colorize_text_styles(string)
          .should eq string.colorize.strikethrough.to_s
      end

      it "combines styles" do
        subject.colorize_text_styles("~~*__foo__*~~")
          .should eq "~~#{"*#{"__foo__".colorize.bold}*".colorize.italic}~~"
            .colorize.strikethrough.to_s
      end
    end

    describe "#colorize_code_fences" do
      it "highlights multiline code blocks" do
        code_string = "```\nfoo\nbar\nbaz\n```"
        string = "foo\n\n%s\n\nbar"

        subject.colorize_code_fences(string % code_string, :red)
          .should eq (string % code_string.colorize.red).to_s
      end

      it "highlights inline code blocks" do
        code_string = "`foo bar baz`"
        string = "foo %s bar"

        subject.colorize_code_fences(string % code_string, :red)
          .should eq (string % code_string.colorize.red).to_s
      end
    end

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
        source = Source.new <<-CRYSTAL
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
          CRYSTAL

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
        code = <<-CRYSTAL
          a = 1
          CRYSTAL
        location = Crystal::Location.new("filename", 2, 1)
        subject.affected_code(code, location).should be_nil
      end

      it "works with file-wide location (1, 1) + indented code" do
        code = <<-CRYSTAL
                  a = 1
          CRYSTAL
        location = Crystal::Location.new("filename", 1, 1)
        subject.deansify(subject.affected_code(code, location))
          .should eq "> a = 1\n  ^\n"
      end

      it "returns correct line if it is found" do
        code = <<-CRYSTAL
          a = 1
          CRYSTAL
        location = Crystal::Location.new("filename", 1, 1)
        subject.deansify(subject.affected_code(code, location))
          .should eq "> a = 1\n  ^\n"
      end

      it "returns correct line if it is found" do
        code = <<-CRYSTAL
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
          CRYSTAL

        location = Crystal::Location.new("filename", 6, 1)
        subject.deansify(subject.affected_code(code, location, context_lines: 3))
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
