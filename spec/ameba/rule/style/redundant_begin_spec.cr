require "../../../spec_helper"

module Ameba::Rule::Style
  describe RedundantBegin do
    subject = RedundantBegin.new

    it "passes if there is no redundant begin blocks" do
      expect_no_issues subject, <<-CRYSTAL
        def method
          do_something
        rescue
          do_something_else
        end

        def method
          do_something
          do_something_else
        ensure
          handle_something
        end

        def method
          yield
        rescue
        end

        def method; end
        def method; a = 1; rescue; end
        def method; begin; rescue; end; end
        CRYSTAL
    end

    it "passes if there is a correct begin block in a handler" do
      expect_no_issues subject, <<-CRYSTAL
        def handler_and_expression
          begin
            open_file
          rescue
            close_file
          end
          do_some_stuff
        end

        def multiple_handlers
          begin
            begin1
          rescue
          end

          begin
            begin2
          rescue
          end
        rescue
          do_something_else
        end

        def assign_and_begin
          @result ||=
            begin
              do_something
              do_something_else
              returnit
            end
        rescue
        end

        def inner_handler
          s = begin
              rescue
              end
        rescue
        end

        def begin_and_expression
          begin
            a = 1
            b = 2
          end
          expr
        end
        CRYSTAL
    end

    it "fails if there is a redundant begin block" do
      source = expect_issue subject, <<-CRYSTAL
        def method(a : String) : String
          begin
        # ^^^^^ error: Redundant `begin` block detected
            open_file
            do_some_stuff
          ensure
            close_file
          end
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        def method(a : String) : String
         #{trailing_whitespace}
            open_file
            do_some_stuff
          ensure
            close_file
         #{trailing_whitespace}
        end
        CRYSTAL
    end

    it "fails if there is a redundant begin block in a method without args" do
      source = expect_issue subject, <<-CRYSTAL
        def method
          begin
        # ^^^^^ error: Redundant `begin` block detected
            open_file
          ensure
            close_file
          end
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        def method
         #{trailing_whitespace}
            open_file
          ensure
            close_file
         #{trailing_whitespace}
        end
        CRYSTAL
    end

    it "fails if there is a redundant block in a method with return type" do
      source = expect_issue subject, <<-CRYSTAL
        def method : String
          begin
        # ^^^^^ error: Redundant `begin` block detected
            open_file
          ensure
            close_file
          end
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        def method : String
         #{trailing_whitespace}
            open_file
          ensure
            close_file
         #{trailing_whitespace}
        end
        CRYSTAL
    end

    it "fails if there is a redundant block in a method with multiple args" do
      source = expect_issue subject, <<-CRYSTAL
        def method(a : String,
                  b : String)
          begin
        # ^^^^^ error: Redundant `begin` block detected
            open_file
          ensure
            close_file
          end
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        def method(a : String,
                  b : String)
         #{trailing_whitespace}
            open_file
          ensure
            close_file
         #{trailing_whitespace}
        end
        CRYSTAL
    end

    it "fails if there is a redundant block in a method with multiple args" do
      source = expect_issue subject, <<-CRYSTAL
        def method(a : String,
                  b : String
        )
          begin
        # ^^^^^ error: Redundant `begin` block detected
            open_file
          ensure
            close_file
          end
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        def method(a : String,
                  b : String
        )
         #{trailing_whitespace}
            open_file
          ensure
            close_file
         #{trailing_whitespace}
        end
        CRYSTAL
    end

    it "doesn't report if there is an inner redundant block" do
      expect_no_issues subject, <<-CRYSTAL
        def method
          begin
            open_file
          ensure
            close_file
          end
        rescue
        end
        CRYSTAL
    end

    it "fails if there is a redundant block with yield" do
      source = expect_issue subject, <<-CRYSTAL
        def method
          begin
        # ^^^^^ error: Redundant `begin` block detected
            yield
          ensure
            close_file
          end
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        def method
         #{trailing_whitespace}
            yield
          ensure
            close_file
         #{trailing_whitespace}
        end
        CRYSTAL
    end

    it "fails if there is a redundant block with string with inner quotes" do
      source = expect_issue subject, <<-CRYSTAL
        def method
          begin
        # ^^^^^ error: Redundant `begin` block detected
            "'"
          rescue
          end
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        def method
         #{trailing_whitespace}
            "'"
          rescue
         #{trailing_whitespace}
        end
        CRYSTAL
    end

    it "fails if there is top level redundant block in a method" do
      source = expect_issue subject, <<-CRYSTAL
        def method
          begin
        # ^^^^^ error: Redundant `begin` block detected
            a = 1
            b = 2
          end
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        def method
         #{trailing_whitespace}
            a = 1
            b = 2
         #{trailing_whitespace}
        end
        CRYSTAL
    end

    it "doesn't report if begin-end block in a proc literal" do
      expect_no_issues subject, <<-CRYSTAL
        foo = ->{
          begin
            raise "Foo!"
          rescue ex
            pp ex
          end
        }
        CRYSTAL
    end
  end
end
