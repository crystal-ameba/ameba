require "../../spec_helper"

class Ameba::Source
  describe Rewriter do
    code = "puts(:hello, :world)"
    hello = {5, 11}
    comma_space = {11, 13}
    world = {13, 19}

    it "can remove" do
      rewriter = Rewriter.new(code)
      rewriter.remove(*hello)
      rewriter.process.should eq "puts(, :world)"
    end

    it "can insert before" do
      rewriter = Rewriter.new(code)
      rewriter.insert_before(*world, "42, ")
      rewriter.process.should eq "puts(:hello, 42, :world)"
    end

    it "can insert after" do
      rewriter = Rewriter.new(code)
      rewriter.insert_after(*hello, ", 42")
      rewriter.process.should eq "puts(:hello, 42, :world)"
    end

    it "can wrap" do
      rewriter = Rewriter.new(code)
      rewriter.wrap(*hello, '[', ']')
      rewriter.process.should eq "puts([:hello], :world)"
    end

    it "can replace" do
      rewriter = Rewriter.new(code)
      rewriter.replace(*hello, ":hi")
      rewriter.process.should eq "puts(:hi, :world)"
    end

    it "accepts crossing deletions" do
      rewriter = Rewriter.new(code)
      rewriter.remove(hello[0], comma_space[1])
      rewriter.remove(comma_space[0], world[1])
      rewriter.process.should eq "puts()"
    end

    it "accepts multiple actions" do
      rewriter = Rewriter.new(code)
      rewriter.replace(*comma_space, " => ")
      rewriter.wrap(hello[0], world[1], '{', '}')
      rewriter.replace(*world, ":everybody")
      rewriter.wrap(*world, '[', ']')
      rewriter.process.should eq "puts({:hello => [:everybody]})"
    end

    it "can wrap the same range" do
      rewriter = Rewriter.new(code)
      rewriter.wrap(*hello, '(', ')')
      rewriter.wrap(*hello, '[', ']')
      rewriter.process.should eq "puts([(:hello)], :world)"
    end

    it "can insert on empty ranges" do
      rewriter = Rewriter.new(code)
      rewriter.insert_before(hello[0], '{')
      rewriter.replace(hello[0], hello[0], 'x')
      rewriter.insert_after(hello[0], '}')
      rewriter.insert_before(hello[1], '[')
      rewriter.replace(hello[1], hello[1], 'y')
      rewriter.insert_after(hello[1], ']')
      rewriter.process.should eq "puts({x}:hello[y], :world)"
    end

    it "can replace the same range" do
      rewriter = Rewriter.new(code)
      rewriter.replace(*hello, ":hi")
      rewriter.replace(*hello, ":hey")
      rewriter.process.should eq "puts(:hey, :world)"
    end

    it "can swallow insertions" do
      rewriter = Rewriter.new(code)
      rewriter.wrap(hello[0] + 1, hello[1], "__", "__")
      rewriter.replace(world[0], world[1] - 2, "xx")
      rewriter.replace(hello[0], world[1], ":hi")
      rewriter.process.should eq "puts(:hi)"
    end

    it "rejects out-of-range ranges" do
      rewriter = Rewriter.new(code)
      expect_raises(IndexError) { rewriter.insert_before(0, 100, "hola") }
    end

    it "ignores trivial actions" do
      rewriter = Rewriter.new(code)
      rewriter.empty?.should be_true

      # This is a trivial wrap
      rewriter.wrap(2, 5, "", "")
      rewriter.empty?.should be_true

      # This is a trivial deletion
      rewriter.remove(2, 2)
      rewriter.empty?.should be_true

      rewriter.remove(2, 5)
      rewriter.empty?.should be_false
    end
  end
end
