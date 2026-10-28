require "../spec_helper"

module Ameba
  describe Source do
    describe ".new" do
      it "allows to create a source by code and path" do
        source = Source.new("code", "foo.cr")
        source.path.should eq Path["foo.cr"]
        source.project_path.should eq source.path
        source.code.should eq "code"
        source.lines.should eq ["code"]
      end
    end

    describe "#fullpath" do
      it "returns an absolute path of the source" do
        path = Path["source_spec.cr"]

        source = Source.new(path: path)
        source.fullpath.should eq path.expand
      end

      it "returns fullpath if path is blank" do
        source = Source.new
        source.fullpath.should eq Path[Dir.current]
      end
    end

    describe "#spec?" do
      it "returns true if the source is a spec file" do
        source = Source.new(path: "source_spec.cr")
        source.spec?.should be_true
      end

      it "returns false if the source is not a spec file" do
        source = Source.new(path: "source.cr")
        source.spec?.should be_false
      end
    end

    describe "#pos" do
      it "works" do
        source = Source.new <<-CRYSTAL
          foo
          bar
          fizz
          buzz
          CRYSTAL

        location = Crystal::Location.new("", 2, 1)
        end_location = Crystal::Location.new("", 3, 4)

        range = Range.new(
          source.pos(location),
          source.pos(end_location, end: true),
          exclusive: true,
        )
        source.code[range].should eq <<-CRYSTAL
          bar
          fizz
          CRYSTAL
      end

      it "works with CRLF line endings" do
        source = Source.new("foo\r\nbar\r\nfizz\r\nbuzz")

        location = Crystal::Location.new("", 2, 1)
        end_location = Crystal::Location.new("", 3, 4)

        range = Range.new(
          source.pos(location),
          source.pos(end_location, end: true),
          exclusive: true,
        )
        source.code[range].should eq "bar\r\nfizz"
      end

      it "works with mixed line endings and multibyte characters" do
        source = Source.new("ü\r\nbar\nbüzz")

        source.pos(Crystal::Location.new("", 1, 1)).should eq 0
        source.pos(Crystal::Location.new("", 2, 1)).should eq 3
        source.pos(Crystal::Location.new("", 3, 2)).should eq 8
        source.code[8].should eq 'ü'
      end

      it "works with empty lines and a trailing new line" do
        source = Source.new("\nfoo\n")

        source.pos(Crystal::Location.new("", 1, 1)).should eq 0
        source.pos(Crystal::Location.new("", 2, 1)).should eq 1
        source.pos(Crystal::Location.new("", 3, 1)).should eq 5
      end

      it "works with an empty code" do
        source = Source.new

        source.pos(Crystal::Location.new("", 1, 1)).should eq 0
      end

      it "works after the code is corrected" do
        source = Source.new("foo   \nbar")
        location = Crystal::Location.new("", 2, 1)

        source.pos(location).should eq 7

        Rule::Layout::TrailingWhitespace.new.catch(source)
        source.correct!.should be_true
        source.code.should eq "foo\nbar"

        source.pos(location).should eq 4
      end
    end

    describe "#correct!" do
      it "skips disabled issues" do
        source = Source.new <<-CRYSTAL
          foo.match("bar").not_nil! # ameba:disable Lint/NotNilAfterNoBang
          CRYSTAL

        rule = Rule::Lint::NotNilAfterNoBang.new
        rule.catch(source)

        source.issues.size.should eq 1
        source.issues.first.enabled?.should be_false
        source.correct!.should be_false
        source.code.should contain ".not_nil!"
      end

      it "corrects enabled issues" do
        source = Source.new <<-CRYSTAL
          foo.match("bar").not_nil!
          CRYSTAL

        rule = Rule::Lint::NotNilAfterNoBang.new
        rule.catch(source)

        source.issues.size.should eq 1
        source.issues.first.enabled?.should be_true
        source.correct!.should be_true
        source.code.should_not contain ".not_nil!"
      end
    end

    describe "#ast" do
      it "parses an ECR file" do
        source = Source.new <<-ECR, "filename.ecr"
          hello <%= "world" %>
          ECR

        source.ast.to_s.should eq <<-CRYSTAL
          __str__ << "hello "
          ("world")
            .to_s(__str__)

          CRYSTAL
      end

      it "raises an exception when ECR parsing fails" do
        source = Source.new <<-ECR, "filename.ecr"
          hello <%= "world" >
          ECR

        expect_raises(Crystal::SyntaxException) do
          source.ast
        end
      end
    end
  end
end
