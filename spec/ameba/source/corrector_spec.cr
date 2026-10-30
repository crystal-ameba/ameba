require "../../spec_helper"

class Ameba::Source
  describe Corrector do
    code = "foo(bar)"

    context "with exclusive range" do
      it "#replace" do
        corrector = Corrector.new(code)
        corrector.replace(4...7, "baz")
        corrector.process.should eq "foo(baz)"
      end

      it "#wrap" do
        corrector = Corrector.new(code)
        corrector.wrap(4...7, "[", "]")
        corrector.process.should eq "foo([bar])"
      end

      it "#remove" do
        corrector = Corrector.new(code)
        corrector.remove(3...8)
        corrector.process.should eq "foo"
      end

      it "#insert_before" do
        corrector = Corrector.new(code)
        corrector.insert_before(4...7, "@")
        corrector.process.should eq "foo(@bar)"
      end

      it "#insert_after" do
        corrector = Corrector.new(code)
        corrector.insert_after(4...7, "?")
        corrector.process.should eq "foo(bar?)"
      end

      it "#remove_trailing" do
        corrector = Corrector.new(code)
        corrector.remove_trailing(0...8, 5)
        corrector.process.should eq "foo"
      end
    end

    context "with inclusive range" do
      it "#replace" do
        corrector = Corrector.new(code)
        corrector.replace(4..6, "baz")
        corrector.process.should eq "foo(baz)"
      end

      it "#wrap" do
        corrector = Corrector.new(code)
        corrector.wrap(4..6, "[", "]")
        corrector.process.should eq "foo([bar])"
      end

      it "#remove" do
        corrector = Corrector.new(code)
        corrector.remove(3..7)
        corrector.process.should eq "foo"
      end

      it "#insert_before" do
        corrector = Corrector.new(code)
        corrector.insert_before(4..6, "@")
        corrector.process.should eq "foo(@bar)"
      end

      it "#insert_after" do
        corrector = Corrector.new(code)
        corrector.insert_after(4..6, "?")
        corrector.process.should eq "foo(bar?)"
      end

      it "#remove_trailing" do
        corrector = Corrector.new(code)
        corrector.remove_trailing(0..7, 5)
        corrector.process.should eq "foo"
      end
    end

    context "with locations" do
      it "works with multiple lines" do
        corrector = Corrector.new("foo\nbar(baz)\n")
        corrector.replace({2, 5}, {2, 7}, "qux")
        corrector.process.should eq "foo\nbar(qux)\n"
      end

      it "works with `Crystal::Location`" do
        corrector = Corrector.new("foo\nbar(baz)\n")
        corrector.replace(
          Crystal::Location.new("", 2, 5),
          Crystal::Location.new("", 2, 7),
          "qux",
        )
        corrector.process.should eq "foo\nbar(qux)\n"
      end

      it "works with CRLF line endings" do
        corrector = Corrector.new("foo\r\nbar(baz)\r\n")
        corrector.replace({2, 5}, {2, 7}, "qux")
        corrector.process.should eq "foo\r\nbar(qux)\r\n"
      end

      it "works with mixed line endings and multibyte characters" do
        corrector = Corrector.new("ü\r\nbär\nbaz(qüx)")
        corrector.replace({3, 5}, {3, 7}, "foo")
        corrector.process.should eq "ü\r\nbär\nbaz(foo)"
      end

      it "works with empty lines" do
        corrector = Corrector.new("\n\nfoo(bar)")
        corrector.wrap({3, 5}, {3, 7}, "[", "]")
        corrector.process.should eq "\n\nfoo([bar])"
      end

      it "works with locations past the last line" do
        corrector = Corrector.new("foo")
        corrector.insert_before({2, 1}, "\n")
        corrector.process.should eq "foo\n"
      end
    end
  end
end
