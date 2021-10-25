require "../../spec_helper"

private def dummy_issue(code,
                        message,
                        position : {Int32, Int32}?,
                        end_position : {Int32, Int32}?,
                        path = "")
  location, end_location = nil, nil
  location = Crystal::Location.new(path, *position) if position
  end_location = Crystal::Location.new(path, *end_position) if end_position

  Ameba::Issue.new(
    code: code,
    rule: Ameba::DummyRule.new,
    location: location,
    end_location: end_location,
    message: message
  )
end

private def expect_invalid_location(code,
                                    position,
                                    end_position,
                                    message exception_message,
                                    file = __FILE__,
                                    line = __LINE__)
  expect_raises Exception, exception_message, file, line do
    Ameba::Spec::AnnotatedSource.new(
      lines: code.lines,
      issues: [dummy_issue(code, "Message", position, end_position, "path")]
    )
  end
end

module Ameba::Spec
  describe AnnotatedSource do
    annotated_text = <<-EOS
      line 1
        # ^^ error: Message 1
      line 2 # error: Message 2
      EOS

    text_without_annotations = <<-EOS
      line 1
      line 2
      EOS

    text_without_source = <<-EOS
      # ^ error: Message 1
      # ^ error: Message 2
      EOS

    describe ".parse" do
      it "accepts annotated text" do
        annotated_source = AnnotatedSource.parse(annotated_text)
        annotated_source.lines.should eq ["line 1", "line 2"]
        annotated_source.annotations.should eq [
          {1, "  # ^^ error: ", "Message 1"},
          {2, "", "Message 2"},
        ]
      end

      it "accepts text containing source only and no annotations" do
        annotated_source = AnnotatedSource.parse(text_without_annotations)
        annotated_source.lines.should eq ["line 1", "line 2"]
        annotated_source.annotations.should be_empty
      end

      it "accepts text containing annotations only and no source" do
        annotated_source = AnnotatedSource.parse(text_without_source)
        annotated_source.lines.should be_empty
        annotated_source.annotations.should eq [
          {1, "# ^ error: ", "Message 1"},
          {1, "# ^ error: ", "Message 2"},
        ]
      end

      it "accepts RuboCop-style annotations" do
        annotated_source = AnnotatedSource.parse <<-EOS
          line 1
              ^^ Message
          line 2
          EOS

        annotated_source.lines.should eq ["line 1", "line 2"]

        annotated_source.annotations.should eq [
          {1, "    ^^ ", "Message"},
        ]
      end
    end

    describe "#==" do
      it "accepts source lines ending with annotations" do
        expected = AnnotatedSource.parse <<-EOS
          line 1 # error: Message
          line 2
          EOS

        actual = AnnotatedSource.parse <<-EOS
          line 1
            # ^^ error: Message
          line 2
          EOS

        actual.should eq expected
      end

      it "accepts annotations that are abbreviated using '[...]'" do
        expected = AnnotatedSource.parse <<-EOS
          line 1 # error: Message [...]
          line 2
            # ^^ error: M[...]s[...]g[...] 2
          EOS

        actual = AnnotatedSource.parse <<-EOS
          line 1
            # ^^ error: Message 1
          line 2
            # ^^ error: Message 2
          EOS

        actual.should eq expected
      end
    end

    describe "#to_s" do
      it "accepts annotated text" do
        annotated_source = AnnotatedSource.parse(annotated_text)
        annotated_source.to_s.should eq annotated_text
      end

      it "accepts text containing source only and no annotations" do
        annotated_source = AnnotatedSource.parse(text_without_annotations)
        annotated_source.to_s.should eq text_without_annotations
      end

      it "accepts text containing annotations only and no source" do
        annotated_source = AnnotatedSource.parse(text_without_source)
        annotated_source.to_s.should eq text_without_source
      end
    end

    describe ".new(lines, annotations)" do
      it "sorts the annotations" do
        annotated_source = AnnotatedSource.new [] of String, [
          {2, "", "Annotation C"},
          {1, "", "Annotation B"},
          {1, "", "Annotation A"},
        ]
        annotated_source.annotations.should eq [
          {1, "", "Annotation A"},
          {1, "", "Annotation B"},
          {2, "", "Annotation C"},
        ]
      end
    end

    describe ".new(lines, issues)" do
      it "raises an exception if issue location is nil" do
        expect_invalid_location text_without_annotations,
          position: nil,
          end_position: nil,
          message: "Missing location for issue 'Message'"
      end

      it "raises an exception if issue starts at column 0" do
        expect_invalid_location text_without_annotations,
          position: {1, 0},
          end_position: nil,
          message: "Invalid issue location: path:1:0"
      end

      it "raises an exception if issue starts at line 0" do
        expect_invalid_location text_without_annotations,
          position: {0, 1},
          end_position: nil,
          message: "Invalid issue location: path:0:1"
      end

      it "raises an exception if issue starts at a non-existent line" do
        expect_invalid_location text_without_annotations,
          position: {3, 1},
          end_position: nil,
          message: "Invalid issue location: path:3:1"
      end

      it "raises an exception if issue ends at column 0" do
        expect_invalid_location text_without_annotations,
          position: {1, 1},
          end_position: {2, 0},
          message: "Invalid issue end location: path:2:0"
      end

      it "raises an exception if issue ends at a non-existent line" do
        expect_invalid_location text_without_annotations,
          position: {1, 1},
          end_position: {3, 1},
          message: "Invalid issue end location: path:3:1"
      end

      it "raises an exception if starting column number is greater than ending column number" do
        expect_invalid_location text_without_annotations,
          position: {1, 2},
          end_position: {1, 1},
          message: <<-MSG
            Invalid issue location
              start: path:1:2
              end:   path:1:1
            MSG
      end

      it "raises an exception if starting line number is greater than ending line number" do
        expect_invalid_location text_without_annotations,
          position: {2, 1},
          end_position: {1, 1},
          message: <<-MSG
            Invalid issue location
              start: path:2:1
              end:   path:1:1
            MSG
      end
    end
  end
end
