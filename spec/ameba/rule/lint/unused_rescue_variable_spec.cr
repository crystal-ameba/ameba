require "../../../spec_helper"

module Ameba::Rule::Lint
  describe UnusedRescueVariable do
    subject = UnusedRescueVariable.new

    it "passes if rescue has no variable" do
      expect_no_issues subject, <<-CRYSTAL
        begin
          raise MyException.new("OH NO!")
        rescue MyException
          puts "Rescued MyException"
        end
        CRYSTAL
    end

    it "passes if rescue variable is used" do
      expect_no_issues subject, <<-CRYSTAL
        begin
          raise MyException.new("OH NO!")
        rescue ex : MyException
          puts ex.message
        end
        CRYSTAL
    end

    it "passes if rescue variable is used in multiple statements" do
      expect_no_issues subject, <<-CRYSTAL
        begin
          raise MyException.new("OH NO!")
        rescue ex : MyException
          puts ex.class
          puts ex.message
        end
        CRYSTAL
    end

    it "fails if rescue variable is not used" do
      expect_issue subject, <<-CRYSTAL
        begin
          raise MyException.new("OH NO!")
        rescue ex : MyException
             # ^^ error: Unused `rescue` variable `ex`
          puts "Rescued MyException"
        end
        CRYSTAL
    end

    it "fails if rescue variable is not used with multiple exception types" do
      expect_issue subject, <<-CRYSTAL
        begin
          raise MyException.new("OH NO!")
        rescue ex : MyException | ArgumentError
             # ^^ error: Unused `rescue` variable `ex`
          puts "Rescued exception"
        end
        CRYSTAL
    end

    it "fails if rescue variable is not used with generic exception type" do
      expect_issue subject, <<-CRYSTAL
        begin
          raise Exception.new("OH NO!")
        rescue ex : Exception
             # ^^ error: Unused `rescue` variable `ex`
          puts "Rescued Exception"
        end
        CRYSTAL
    end

    it "passes when variable is used in nested block" do
      expect_no_issues subject, <<-CRYSTAL
        begin
          raise MyException.new("OH NO!")
        rescue ex : MyException
          [1, 2, 3].each do |i|
            puts ex.message
          end
        end
        CRYSTAL
    end

    it "fails when variable is shadowed by nested block parameter" do
      expect_issue subject, <<-CRYSTAL
        begin
          raise MyException.new("OH NO!")
        rescue ex : MyException
             # ^^ error: Unused `rescue` variable `ex`
          ([1, 2, 3]).each do |ex|
            puts ex
          end
        end
        CRYSTAL
    end

    it "fails when variable is shadowed by an uninitialized variable" do
      expect_issue subject, <<-CRYSTAL
        begin
          raise MyException.new("OH NO!")
        rescue ex : MyException
             # ^^ error: Unused `rescue` variable `ex`
          ex = uninitialized ArgumentError
        end
        CRYSTAL
    end

    it "fails when variable is shadowed by an assignment" do
      expect_issue subject, <<-CRYSTAL
        begin
          raise MyException.new("OH NO!")
        rescue ex : MyException
             # ^^ error: Unused `rescue` variable `ex`
          ex = 42
        end
        CRYSTAL
    end

    it "fails when variable is shadowed by an multiple assignment" do
      expect_issue subject, <<-CRYSTAL
        begin
          raise MyException.new("OH NO!")
        rescue ex : MyException
             # ^^ error: Unused `rescue` variable `ex`
          ex, ox = 42, 24
        end
        CRYSTAL
    end

    it "passes when variable is used in interpolation" do
      expect_no_issues subject, <<-'CRYSTAL'
        begin
          raise MyException.new("OH NO!")
        rescue ex : MyException
          puts "Error: #{ex.message}"
        end
        CRYSTAL
    end

    it "handles multiple rescue blocks correctly" do
      expect_issue subject, <<-CRYSTAL
        begin
          raise MyException.new("OH NO!")
        rescue ex : MyException
             # ^^ error: Unused `rescue` variable `ex`
          puts "Rescued MyException"
        rescue e : ArgumentError
          puts e.message
        end
        CRYSTAL
    end

    it "passes when all rescue blocks use their variables" do
      expect_no_issues subject, <<-CRYSTAL
        begin
          raise MyException.new("OH NO!")
        rescue ex : MyException
          puts ex.message
        rescue e : ArgumentError
          puts e.message
        end
        CRYSTAL
    end
  end
end
