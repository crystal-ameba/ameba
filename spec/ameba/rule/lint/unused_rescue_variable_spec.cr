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

    it "passes if rescue variable is within `MacroIf`" do
      expect_no_issues subject, <<-'CRYSTAL'
        begin
          raise MyException.new("OH NO!")
        rescue ex : MyException
          {% if flag?(:debug) %}
            STDERR.puts "Error: #{ex.message}"
          {% end %}
        end
        CRYSTAL
    end

    it "passes if rescue variable is within `MacroFor`" do
      expect_no_issues subject, <<-'CRYSTAL'
        begin
          raise MyException.new("OH NO!")
        rescue ex : MyException
          {% for key in %w[foo bar] %}
            STDERR.puts "{{ key.id }}: #{ex.message}"
          {% end %}
        end
        CRYSTAL
    end

    it "passes if rescue variable is within `MacroExpression`" do
      expect_no_issues subject, <<-CRYSTAL
        begin
          raise MyException.new("OH NO!")
        rescue ex : MyException
          puts {{ "ex".id }}
        end
        CRYSTAL
    end

    it "passes if rescue variable is within `MacroVerbatim`" do
      expect_no_issues subject, <<-CRYSTAL
        begin
          raise MyException.new("OH NO!")
        rescue ex : MyException
          {% verbatim do %}
            puts ex
          {% end %}
        end
        CRYSTAL
    end

    it "passes if rescue variable is used within `MacroExpression` after the handler" do
      expect_no_issues subject, <<-CRYSTAL
        def foo
          begin
            raise MyException.new("OH NO!")
          rescue ex : MyException
          end
          puts {{ "ex".id }}
        end
        CRYSTAL
    end

    it "passes if rescue variable is used within `MacroIf` after the handler" do
      expect_no_issues subject, <<-CRYSTAL
        def foo
          begin
            raise MyException.new("OH NO!")
          rescue ex : MyException
          end
          {% if flag?(:debug) %}
            puts ex
          {% end %}
        end
        CRYSTAL
    end

    it "passes if rescue variable is used within `MacroIf` in ensure" do
      expect_no_issues subject, <<-CRYSTAL
        begin
          raise MyException.new("OH NO!")
        rescue ex : MyException
        ensure
          {% if flag?(:debug) %}
            puts ex
          {% end %}
        end
        CRYSTAL
    end

    it "passes if rescue variable is used within `MacroIf` in a subsequent block" do
      expect_no_issues subject, <<-CRYSTAL
        def foo
          begin
            raise MyException.new("OH NO!")
          rescue ex : MyException
          end
          [1].each do
            {% if flag?(:debug) %}
              puts ex
            {% end %}
          end
        end
        CRYSTAL
    end

    it "fails if rescue variable is used only within `MacroIf` before the handler" do
      expect_issue subject, <<-CRYSTAL
        def foo
          {% if flag?(:debug) %}
            puts ex
          {% end %}
          begin
            raise MyException.new("OH NO!")
          rescue ex : MyException
               # ^^ error: Unused `rescue` variable `ex`
          end
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

    it "fails when variable is shadowed by nested unpacked block parameter" do
      expect_issue subject, <<-CRYSTAL
        begin
          raise MyException.new("OH NO!")
        rescue ex : MyException
             # ^^ error: Unused `rescue` variable `ex`
          [{1, 2}].each do |(ex, y)|
            puts y
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

    it "passes when variable is used after the exception handler" do
      expect_no_issues subject, <<-CRYSTAL
        def foo
          begin
            raise MyException.new("OH NO!")
          rescue ex : MyException
          end
          puts ex
        end

        def bar
          begin
            raise MyException.new("OH NO!")
          rescue ex : MyException
          end
          [1].each { puts ex }
        end
        CRYSTAL
    end

    it "passes when variable is used in ensure" do
      expect_no_issues subject, <<-CRYSTAL
        begin
          raise MyException.new("OH NO!")
        rescue ex : MyException
        ensure
          puts ex
        end
        CRYSTAL
    end

    it "passes when variable is used in ensure of a nested handler on return" do
      expect_no_issues subject, <<-CRYSTAL
        def foo
          begin
            raise "x"
          rescue ex
            begin
              return
            ensure
              puts ex
            end
          end
        end
        CRYSTAL
    end

    it "passes when variable is used in ensure of an outer handler on return" do
      expect_no_issues subject, <<-CRYSTAL
        def foo
          ex = nil
          begin
            begin
              raise "x"
            rescue ex
              return
            end
          ensure
            puts ex
          end
        end
        CRYSTAL
    end

    it "passes when variable is used in ensure on break" do
      expect_no_issues subject, <<-CRYSTAL
        loop do
          begin
            raise "x"
          rescue ex
            begin
              break
            ensure
              puts ex
            end
          end
        end
        CRYSTAL
    end

    it "passes when variable is used in ensure after a raising call" do
      expect_no_issues subject, <<-CRYSTAL
        begin
          raise "x"
        rescue ex
          bar
          ex = nil
        ensure
          puts ex
        end
        CRYSTAL
    end

    it "fails when variable is not used in ensure on return" do
      expect_issue subject, <<-CRYSTAL
        def foo
          begin
            raise "x"
          rescue ex
               # ^^ error: Unused `rescue` variable `ex`
            begin
              return
            ensure
              puts "done"
            end
          end
        end
        CRYSTAL
    end

    it "fails when variable is overwritten after the exception handler" do
      expect_issue subject, <<-CRYSTAL
        def foo
          begin
            raise MyException.new("OH NO!")
          rescue ex : MyException
               # ^^ error: Unused `rescue` variable `ex`
          end
          ex = nil
          puts ex
        end
        CRYSTAL
    end

    it "fails when variable is overwritten before being referenced in a block" do
      expect_issue subject, <<-CRYSTAL
        def foo
          begin
            raise MyException.new("OH NO!")
          rescue ex : MyException
               # ^^ error: Unused `rescue` variable `ex`
          end
          ex = nil
          [1].each { puts ex }
        end
        CRYSTAL
    end

    it "passes when variable is referenced in a block preceding the rescue" do
      expect_no_issues subject, <<-CRYSTAL
        def foo
          ex = nil
          callback = -> { puts ex }
          begin
            raise MyException.new("OH NO!")
          rescue ex : MyException
          end
          callback.call
        end
        CRYSTAL
    end

    it "passes when variable address is taken before the rescue" do
      expect_no_issues subject, <<-CRYSTAL
        def foo
          ex = nil
          ptr = pointerof(ex)
          begin
            raise MyException.new("OH NO!")
          rescue ex : MyException
          end
          puts ptr.value
        end
        CRYSTAL
    end

    it "fails when variable address is taken after being overwritten" do
      expect_issue subject, <<-CRYSTAL
        def foo
          begin
            raise MyException.new("OH NO!")
          rescue ex : MyException
               # ^^ error: Unused `rescue` variable `ex`
          end
          ex = nil
          ptr = pointerof(ex)
          puts ptr.value
        end
        CRYSTAL
    end

    context "with captured variable" do
      it "fails if rescue variable is not used within a block" do
        expect_issue subject, <<-CRYSTAL
          ex = nil
          [1].each do
            begin
              raise "x"
            rescue ex
                 # ^^ error: Unused `rescue` variable `ex`
              puts "handled"
            end
          end
          CRYSTAL
      end

      it "fails if rescue variable is not used within a proc" do
        expect_issue subject, <<-CRYSTAL
          def foo
            ex = nil
            callback = -> do
              begin
                raise "x"
              rescue ex
                   # ^^ error: Unused `rescue` variable `ex`
                puts "handled"
              end
            end
            callback.call
          end
          CRYSTAL
      end

      it "fails if rescue variable is not used within a nested block" do
        expect_issue subject, <<-CRYSTAL
          ex = nil
          [1].each do
            [2].each do
              begin
                raise "x"
              rescue ex
                   # ^^ error: Unused `rescue` variable `ex`
              end
            end
          end
          CRYSTAL
      end

      it "fails if rescue variable is overwritten before being used" do
        expect_issue subject, <<-CRYSTAL
          ex = nil
          [1].each do
            begin
              raise "x"
            rescue ex
                 # ^^ error: Unused `rescue` variable `ex`
            end
            ex = nil
            puts ex
          end
          puts ex
          CRYSTAL
      end

      it "passes if rescue variable is used after the handler" do
        expect_no_issues subject, <<-CRYSTAL
          ex = nil
          [1].each do
            begin
              raise "x"
            rescue ex
            end
            puts ex
          end
          CRYSTAL
      end

      it "passes if rescue variable is used outside of a block" do
        expect_no_issues subject, <<-CRYSTAL
          ex = nil
          [1].each do
            begin
              raise "x"
            rescue ex
            end
          end
          puts ex
          CRYSTAL
      end

      it "passes if rescue variable is used outside of a proc" do
        expect_no_issues subject, <<-CRYSTAL
          def foo
            ex = nil
            callback = -> do
              begin
                raise "x"
              rescue ex
              end
              nil
            end
            callback.call
            ex
          end
          CRYSTAL
      end

      it "passes if rescue variable is used outside of a block after `next`" do
        expect_no_issues subject, <<-CRYSTAL
          ex = nil
          [1].each do
            begin
              raise "x"
            rescue ex
              next
            end
          end
          puts ex
          CRYSTAL
      end

      it "passes if rescue variable is used in a subsequent block invocation" do
        expect_no_issues subject, <<-CRYSTAL
          ex = nil
          [1, 2].each do
            puts ex
            begin
              raise "x"
            rescue ex
            end
          end
          CRYSTAL
      end

      it "passes if rescue variable is used in a nested block after the handler" do
        expect_no_issues subject, <<-CRYSTAL
          ex = nil
          [1].each do
            begin
              raise "x"
            rescue ex
            end
            [2].each { puts ex }
          end
          CRYSTAL
      end
    end

    it "reports unused rescue variable within an accessor macro block" do
      expect_issue subject, <<-CRYSTAL
        class Foo
          getter bar : Int32 do
            begin
              compute
            rescue ex
                 # ^^ error: Unused `rescue` variable `ex`
              0
            end
          end
        end
        CRYSTAL
    end

    it "reports unused rescue variable within a record macro block" do
      expect_issue subject, <<-CRYSTAL
        record Foo, x : Int32 do
          def bar
            compute
          rescue ex
               # ^^ error: Unused `rescue` variable `ex`
            0
          end
        end
        CRYSTAL
    end

    it "reports unused rescue variable within a top-level multi-assignment" do
      expect_issue subject, <<-CRYSTAL
        a, b = begin
          foo { 1 }
        rescue ex
             # ^^ error: Unused `rescue` variable `ex`
          {1, 2}
        end
        CRYSTAL
    end

    it "reports unused rescue variable within a top-level type declaration" do
      expect_issue subject, <<-CRYSTAL
        x : Int32 = begin
          foo { 1 }
        rescue ex
             # ^^ error: Unused `rescue` variable `ex`
          1
        end
        CRYSTAL
    end
  end
end
