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
  end
end
