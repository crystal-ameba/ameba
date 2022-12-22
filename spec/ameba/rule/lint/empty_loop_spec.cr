require "../../../spec_helper"

module Ameba::Rule::Lint
  describe EmptyLoop do
    subject = EmptyLoop.new

    it "does not report if there are not empty loops" do
      expect_no_issues subject, <<-CRYSTAL
        a = 1

        while a < 10
          a += 1
        end

        until a == 10
         a += 1
        end

        loop do
          a += 1
        end
        CRYSTAL
    end

    it "reports if there is an empty while loop" do
      expect_issue subject, <<-CRYSTAL
        a = 1
        while true
        # ^^^^^^^^ error: Empty loop detected
        end
        CRYSTAL
    end

    it "doesn't report if while loop has non-literals in cond block" do
      expect_no_issues subject, <<-CRYSTAL
        a = 1
        while a = gets.to_s
          # nothing here
        end
        CRYSTAL
    end

    it "reports if there is an empty until loop" do
      expect_issue subject, <<-CRYSTAL
        do_something
        until false
        # ^^^^^^^^^ error: Empty loop detected
        end
        CRYSTAL
    end

    it "doesn't report if until loop has non-literals in cond block" do
      expect_no_issues subject, <<-CRYSTAL
        until socket_open?
        end
        CRYSTAL
    end

    it "reports if there an empty loop" do
      expect_issue subject, <<-CRYSTAL
        a = 1
        loop do
        # ^^^^^ error: Empty loop detected
        end
        CRYSTAL
    end
  end
end
