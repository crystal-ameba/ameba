require "../../../spec_helper"

module Ameba::Rule::Lint
  describe LiteralInCondition do
    subject = LiteralInCondition.new

    it "passes if there is not literals in conditional" do
      expect_no_issues subject, <<-CRYSTAL
        if a == 2
          :ok
        end

        :ok unless b

        case string
        when "a"
          :ok
        when "b"
          :ok
        end

        unless a.nil?
          :ok
        end
        CRYSTAL
    end

    it "fails if there is a predicate with non-literals" do
      expect_issue subject, <<-CRYSTAL
        :ok if     [foo, bar]
                 # ^^^^^^^^^^ error: Literal value found in conditional
        :ok unless [foo, bar]
                 # ^^^^^^^^^^ error: Literal value found in conditional

        while [foo, bar]
            # ^^^^^^^^^^ error: Literal value found in conditional
          :ok
        end

        until [foo, bar]
            # ^^^^^^^^^^ error: Literal value found in conditional
          :ok
        end
        CRYSTAL
    end

    it "fails if there is a predicate in `if` conditional" do
      expect_issue subject, <<-CRYSTAL
        if "string"
         # ^^^^^^^^ error: Literal value found in conditional
          :ok
        end
        CRYSTAL
    end

    it "fails if there is a predicate in `unless` conditional" do
      expect_issue subject, <<-CRYSTAL
        unless true
             # ^^^^ error: Literal value found in conditional
          :ok
        end
        CRYSTAL
    end

    it "fails if there is a predicate in `while` conditional" do
      expect_issue subject, <<-CRYSTAL
        while 1
            # ^ error: Literal value found in conditional
          :ok
        end
        CRYSTAL
    end

    it "fails if there is a `false` predicate in `while` conditional" do
      expect_issue subject, <<-CRYSTAL
        while false
            # ^^^^^ error: Literal value found in conditional
          :ok
        end
        CRYSTAL
    end

    it "passes if there is a `true` predicate in `while` conditional" do
      expect_no_issues subject, <<-CRYSTAL
        while true
          :ok
        end
        CRYSTAL
    end

    it "fails if there is a predicate in `until` conditional" do
      expect_issue subject, <<-CRYSTAL
        until true
            # ^^^^ error: Literal value found in conditional
          :foo
        end
        CRYSTAL
    end

    describe "range" do
      it "reports range with literals" do
        expect_issue subject, <<-CRYSTAL
          case 1..2
             # ^^^^ error: Literal value found in conditional
          end
          CRYSTAL
      end

      it "doesn't report range with non-literals" do
        expect_no_issues subject, <<-CRYSTAL
          case (1..a)
          end
          CRYSTAL
      end
    end

    describe "array" do
      it "reports array with literals" do
        expect_issue subject, <<-CRYSTAL
          case [1, 2, 3]
             # ^^^^^^^^^ error: Literal value found in conditional
          when :array
            :ok
          when :not_array
            :also_ok
          end
          CRYSTAL
      end

      it "doesn't report array with non-literals" do
        expect_no_issues subject, <<-CRYSTAL
          a, b = 1, 2
          case [1, 2, a]
          when :array
            :ok
          when :not_array
            :also_ok
          end
          CRYSTAL
      end
    end

    describe "hash" do
      it "reports hash with literals" do
        expect_issue subject, <<-CRYSTAL
          case { "name" => 1, 33 => 'b' }
             # ^^^^^^^^^^^^^^^^^^^^^^^^^^ error: Literal value found in conditional
          when :hash
            :ok
          end
          CRYSTAL
      end

      it "doesn't report hash with non-literals in keys" do
        expect_no_issues subject, <<-CRYSTAL
          case { a => 1, 33 => 'b' }
          when :hash
            :ok
          end
          CRYSTAL
      end

      it "doesn't report hash with non-literals in values" do
        expect_no_issues subject, <<-CRYSTAL
          case { "name" => a, 33 => 'b' }
          when :hash
            :ok
          end
          CRYSTAL
      end
    end

    describe "tuple" do
      it "reports tuple with literals" do
        expect_issue subject, <<-CRYSTAL
          case {1, false}
             # ^^^^^^^^^^ error: Literal value found in conditional
          when {1, _}
            :ok
          end
          CRYSTAL
      end

      it "doesn't report tuple with non-literals" do
        expect_no_issues subject, <<-CRYSTAL
          a, b = 1, 2
          case {1, b}
          when {1, 2}
            :ok
          end
          CRYSTAL
      end
    end

    describe "named tuple" do
      it "reports named tuple with literals" do
        expect_issue subject, <<-CRYSTAL
          case { name: 1, foo: :bar}
             # ^^^^^^^^^^^^^^^^^^^^^ error: Literal value found in conditional
          end
          CRYSTAL
      end

      it "doesn't report named tuple with non-literals" do
        expect_no_issues subject, <<-CRYSTAL
          case { name: a, foo: :bar}
          end
          CRYSTAL
      end
    end
  end
end
