require "../../../spec_helper"

module Ameba::Rule::Lint
  describe AmbiguousAssignment do
    subject = AmbiguousAssignment.new

    context "when using `-`" do
      it "registers an offense with `x`" do
        expect_issue subject, <<-CRYSTAL
          x =- y
          # ^^ error: Suspicious assignment detected. Did you mean `-=`?
          CRYSTAL
      end

      it "registers an offense with `@x`" do
        expect_issue subject, <<-CRYSTAL
          @x =- y
           # ^^ error: Suspicious assignment detected. Did you mean `-=`?
          CRYSTAL
      end

      it "registers an offense with `@@x`" do
        expect_issue subject, <<-CRYSTAL
          @@x =- y
            # ^^ error: Suspicious assignment detected. Did you mean `-=`?
          CRYSTAL
      end

      it "registers an offense with `X`" do
        expect_issue subject, <<-CRYSTAL
          X =- y
          # ^^ error: Suspicious assignment detected. Did you mean `-=`?
          CRYSTAL
      end

      it "does not register an offense when no mistype assignments" do
        expect_no_issues subject, <<-CRYSTAL
          x = 1
          x -= y
          x = -y
          CRYSTAL
      end
    end

    context "when using `+`" do
      it "registers an offense with `x`" do
        expect_issue subject, <<-CRYSTAL
          x =+ y
          # ^^ error: Suspicious assignment detected. Did you mean `+=`?
          CRYSTAL
      end

      it "registers an offense with `@x`" do
        expect_issue subject, <<-CRYSTAL
          @x =+ y
           # ^^ error: Suspicious assignment detected. Did you mean `+=`?
          CRYSTAL
      end

      it "registers an offense with `@@x`" do
        expect_issue subject, <<-CRYSTAL
          @@x =+ y
            # ^^ error: Suspicious assignment detected. Did you mean `+=`?
          CRYSTAL
      end

      it "registers an offense with `X`" do
        expect_issue subject, <<-CRYSTAL
          X =+ y
          # ^^ error: Suspicious assignment detected. Did you mean `+=`?
          CRYSTAL
      end

      it "does not register an offense when no mistype assignments" do
        expect_no_issues subject, <<-CRYSTAL
          x = 1
          x += y
          x = +y
          CRYSTAL
      end
    end

    context "when using `!`" do
      it "registers an offense with `x`" do
        expect_issue subject, <<-CRYSTAL
          x =! y
          # ^^ error: Suspicious assignment detected. Did you mean `!=`?
          CRYSTAL
      end

      it "registers an offense with `@x`" do
        expect_issue subject, <<-CRYSTAL
          @x =! y
           # ^^ error: Suspicious assignment detected. Did you mean `!=`?
          CRYSTAL
      end

      it "registers an offense with `@@x`" do
        expect_issue subject, <<-CRYSTAL
          @@x =! y
            # ^^ error: Suspicious assignment detected. Did you mean `!=`?
          CRYSTAL
      end

      it "registers an offense with `X`" do
        expect_issue subject, <<-CRYSTAL
          X =! y
          # ^^ error: Suspicious assignment detected. Did you mean `!=`?
          CRYSTAL
      end

      it "does not register an offense when no mistype assignments" do
        expect_no_issues subject, <<-CRYSTAL
          x = false
          x != y
          x = !y
          CRYSTAL
      end
    end

    it "reports setter method calls" do
      expect_issue subject, <<-CRYSTAL
        x.foo =-1
            # ^^ error: Suspicious assignment detected. Did you mean `-=`?
        x[0] =+1
           # ^^ error: Suspicious assignment detected. Did you mean `+=`?
        x[0, 1] =! y
              # ^^ error: Suspicious assignment detected. Did you mean `!=`?
        CRYSTAL
    end

    it "does not report setter method calls without mistypes" do
      expect_no_issues subject, <<-CRYSTAL
        x.foo = -1
        x[0] = +1
        x[0] = !y
        x.foo= -1
        CRYSTAL
    end
  end
end
