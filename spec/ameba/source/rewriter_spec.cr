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

    it "keeps non-conflicting corrections recorded in a transaction" do
      rewriter = Rewriter.new(code)
      rewriter.replace(*hello, ":hi")

      rewriter.transaction { rewriter.replace(*world, ":everybody") }.should be_true
      rewriter.process.should eq "puts(:hi, :everybody)"
    end

    it "discards overlapping corrections recorded in a transaction" do
      rewriter = Rewriter.new(code)
      rewriter.replace(*hello, ":hi")

      rewriter.transaction { rewriter.replace(hello[0], world[1], ":greeting") }.should be_false
      rewriter.process.should eq "puts(:hi, :world)"
    end

    it "discards every correction of a conflicting transaction" do
      rewriter = Rewriter.new("abcdef")
      rewriter.replace(1, 2, "X")

      rewriter.transaction do
        rewriter.replace(4, 5, "Y")
        rewriter.replace(1, 3, "Z")
      end.should be_false
      rewriter.process.should eq "aXcdef"
    end

    it "discards a transaction without corrections" do
      rewriter = Rewriter.new("abcdef")

      rewriter.transaction { }.should be_false
      rewriter.empty?.should be_true
    end

    it "discards a transaction leaving the code unchanged" do
      rewriter = Rewriter.new("abcdef")

      rewriter.transaction { rewriter.replace(1, 3, "bc") }.should be_false
      rewriter.empty?.should be_true
    end

    it "keeps earlier corrections if a transaction raises" do
      rewriter = Rewriter.new("abcdef")
      rewriter.replace(1, 2, "X")

      expect_raises(IndexError) do
        rewriter.transaction do
          rewriter.replace(3, 4, "Y")
          rewriter.replace(0, 100, "Z")
        end
      end
      rewriter.process.should eq "aXcdef"
    end

    it "keeps insertions at the boundary of a replacement" do
      rewriter = Rewriter.new("abcdef")
      rewriter.replace(1, 3, "X")

      rewriter.transaction { rewriter.insert_before(3, "Y") }.should be_true
      rewriter.process.should eq "aXYdef"
    end

    it "discards insertions inside a replacement" do
      rewriter = Rewriter.new("abcdef")
      rewriter.replace(1, 3, "X")

      rewriter.transaction { rewriter.insert_before(2, "Y") }.should be_false
      rewriter.process.should eq "aXdef"
    end

    it "discards a replacement over a previously recorded insertion" do
      rewriter = Rewriter.new("abcdef")
      rewriter.insert_before(2, "Y")

      rewriter.transaction { rewriter.replace(1, 3, "X") }.should be_false
      rewriter.process.should eq "abYcdef"
    end

    it "discards ranged insertions contained by a replacement" do
      rewriter = Rewriter.new("abcdef")
      rewriter.replace(1, 5, "X")

      rewriter.transaction { rewriter.insert_before(1, 3, "Y") }.should be_false
      rewriter.transaction { rewriter.insert_after(3, 5, "Y") }.should be_false
      rewriter.process.should eq "aXf"
    end

    it "discards a replacement over contained ranged insertions" do
      rewriter = Rewriter.new("abcdef")
      rewriter.insert_before(1, 3, "Y")

      rewriter.transaction { rewriter.replace(1, 5, "X") }.should be_false
      rewriter.process.should eq "aYbcdef"
    end

    it "discards insertions at the boundaries of a whole-source replacement" do
      [0, 6].each do |pos|
        rewriter = Rewriter.new("abcdef")
        rewriter.replace(0, 6, "X")

        rewriter.transaction { rewriter.insert_before(pos, "Y") }.should be_false
        rewriter.process.should eq "X"

        rewriter = Rewriter.new("abcdef")
        rewriter.insert_before(pos, "Y")

        rewriter.transaction { rewriter.replace(0, 6, "X") }.should be_false
        rewriter.process.should_not eq "X"
      end
    end

    it "discards a wrap with a nested correction conflicting with a contained one" do
      rewriter = Rewriter.new("abcdef")
      rewriter.replace(2, 4, "X")

      rewriter.transaction do
        rewriter.wrap(1, 5, '[', ']')
        rewriter.replace(2, 3, "Y")
      end.should be_false
      rewriter.process.should eq "abXef"
    end

    it "keeps nested wraps in either order" do
      rewriter = Rewriter.new("abcdef")
      rewriter.wrap(1, 5, '[', ']')

      rewriter.transaction { rewriter.wrap(2, 4, '(', ')') }.should be_true
      rewriter.process.should eq "a[b(cd)e]f"

      rewriter = Rewriter.new("abcdef")
      rewriter.wrap(2, 4, '(', ')')

      rewriter.transaction { rewriter.wrap(1, 5, '[', ']') }.should be_true
      rewriter.process.should eq "a[b(cd)e]f"
    end

    it "keeps wraps at the same range" do
      rewriter = Rewriter.new("abcdef")
      rewriter.wrap(1, 4, '[', ']')

      rewriter.transaction { rewriter.wrap(1, 4, '(', ')') }.should be_true
      rewriter.process.should eq "a([bcd])ef"
    end

    it "keeps a wrap with a contained replacement in either order" do
      rewriter = Rewriter.new("abcdef")
      rewriter.wrap(1, 5, '[', ']')

      rewriter.transaction { rewriter.replace(2, 4, "X") }.should be_true
      rewriter.process.should eq "a[bXe]f"

      rewriter = Rewriter.new("abcdef")
      rewriter.replace(2, 4, "X")

      rewriter.transaction { rewriter.wrap(1, 5, '[', ']') }.should be_true
      rewriter.process.should eq "a[bXe]f"
    end

    it "discards crossing wraps" do
      rewriter = Rewriter.new("abcdef")
      rewriter.wrap(1, 4, '[', ']')

      rewriter.transaction { rewriter.wrap(2, 5, '(', ')') }.should be_false
      rewriter.process.should eq "a[bcd]ef"
    end

    it "discards replacements at the same empty range" do
      rewriter = Rewriter.new("abcdef")
      rewriter.replace(2, 2, 'x')

      rewriter.transaction { rewriter.replace(2, 2, 'y') }.should be_false
      rewriter.process.should eq "abxcdef"
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
