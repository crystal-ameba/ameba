require "../../../spec_helper"

module Ameba::Rule::Style
  describe NegatedConditionsInUnless do
    subject = NegatedConditionsInUnless.new

    it "passes with a unless without negated condition" do
      expect_no_issues subject, <<-CRYSTAL
        unless foo
          :ok
        end

        :ok unless bar

        unless baz.empty?
          :ok
        end
        CRYSTAL
    end

    it "reports and autocorrects simple negated condition" do
      source = expect_issue subject, <<-CRYSTAL
        unless !foo
             # ^^^^ error: Avoid negated conditions in `unless` blocks
          :foo
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        if foo
          :foo
        end
        CRYSTAL
    end

    it "reports and autocorrects negated method call" do
      source = expect_issue subject, <<-CRYSTAL
        unless !foo.empty?
             # ^^^^^^^^^^^ error: Avoid negated conditions in `unless` blocks
          :ok
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        if foo.empty?
          :ok
        end
        CRYSTAL
    end

    it "reports and autocorrects parenthesized negated expression" do
      source = expect_issue subject, <<-CRYSTAL
        unless !(a || b)
             # ^^^^^^^^^ error: Avoid negated conditions in `unless` blocks
          :ok
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        if (a || b)
          :ok
        end
        CRYSTAL
    end

    it "reports and autocorrects unless with else" do
      source = expect_issue subject, <<-CRYSTAL
        unless !foo
             # ^^^^ error: Avoid negated conditions in `unless` blocks
          :ok
        else
          :nok
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        if foo
          :ok
        else
          :nok
        end
        CRYSTAL
    end

    it "reports and autocorrects suffix unless" do
      source = expect_issue subject, <<-CRYSTAL
        :ok unless !foo
                 # ^^^^ error: Avoid negated conditions in `unless` blocks
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        :ok if foo
        CRYSTAL
    end

    it "reports and autocorrects suffix unless preceded by `unless` text" do
      source = expect_issue subject, <<-CRYSTAL
        unless_foo = 1 unless !foo
                            # ^^^^ error: Avoid negated conditions in `unless` blocks
        puts "unless" unless !bar
                           # ^^^^ error: Avoid negated conditions in `unless` blocks
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        unless_foo = 1 if foo
        puts "unless" if bar
        CRYSTAL
    end

    it "reports and autocorrects suffix unless preceded by `unless` literals" do
      source = expect_issue subject, <<-CRYSTAL
        a = :unless unless !a
                         # ^^ error: Avoid negated conditions in `unless` blocks
        b = %w(unless) unless !b
                            # ^^ error: Avoid negated conditions in `unless` blocks
        c = /unless/ unless !c
                          # ^^ error: Avoid negated conditions in `unless` blocks
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        a = :unless if a
        b = %w(unless) if b
        c = /unless/ if c
        CRYSTAL
    end

    it "reports and autocorrects suffix unless with a nested suffix unless" do
      source = expect_issue subject, <<-'CRYSTAL'
        (:ok unless !a) unless !b
                             # ^^ error: Avoid negated conditions in `unless` blocks
                  # ^^ error: Avoid negated conditions in `unless` blocks
        "#{:ok unless !c}" unless !d
                                # ^^ error: Avoid negated conditions in `unless` blocks
                    # ^^ error: Avoid negated conditions in `unless` blocks
        CRYSTAL

      expect_correction source, <<-'CRYSTAL'
        (:ok if a) if b
        "#{:ok if c}" if d
        CRYSTAL
    end

    it "reports and autocorrects suffix unless with a multiline body" do
      source = expect_issue subject, <<-CRYSTAL
        foo(1,
          2) unless !bar
                  # ^^^^ error: Avoid negated conditions in `unless` blocks
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        foo(1,
          2) if bar
        CRYSTAL
    end

    it "reports and autocorrects multiline condition with negation" do
      source = expect_issue subject, <<-CRYSTAL
        unless !
             # ^ error: Avoid negated conditions in `unless` blocks
          foo
          :ok
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        if #{""}
          foo
          :ok
        end
        CRYSTAL
    end

    it "reports and autocorrects condition preceded by a comment containing `unless`" do
      source = expect_issue subject, <<-CRYSTAL
        unless # unless
          !foo
        # ^^^^ error: Avoid negated conditions in `unless` blocks
          :ok
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        if # unless
          foo
          :ok
        end
        CRYSTAL
    end

    it "reports and autocorrects suffix condition preceded by a comment containing `unless`" do
      source = expect_issue subject, <<-CRYSTAL
        :ok unless # unless
          !foo
        # ^^^^ error: Avoid negated conditions in `unless` blocks
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        :ok if # unless
          foo
        CRYSTAL
    end

    it "reports and autocorrects condition preceded by multiple comments" do
      source = expect_issue subject, <<-CRYSTAL
        unless # foo
          # unless
          !foo
        # ^^^^ error: Avoid negated conditions in `unless` blocks
          :ok
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        if # foo
          # unless
          foo
          :ok
        end
        CRYSTAL
    end

    it "reports and autocorrects suffix unless followed by a comment containing `unless`" do
      source = expect_issue subject, <<-CRYSTAL
        :ok unless !foo # unless
                 # ^^^^ error: Avoid negated conditions in `unless` blocks
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        :ok if foo # unless
        CRYSTAL
    end

    it "reports and autocorrects double negated condition" do
      source = expect_issue subject, <<-CRYSTAL
        unless !!foo
             # ^^^^^ error: Avoid negated conditions in `unless` blocks
          :ok
        end
        CRYSTAL

      expect_correction source, <<-CRYSTAL
        if !foo
          :ok
        end
        CRYSTAL
    end

    it "reports and doesn't autocorrect suffix unless with a heredoc body" do
      source = expect_issue subject, <<-CRYSTAL
        foo(<<-HEREDOC) unless !bar
                             # ^^^^ error: Avoid negated conditions in `unless` blocks
          unless
          HEREDOC
        CRYSTAL

      expect_no_corrections source
    end

    it "fails if one of AND conditions is negated" do
      source = expect_issue subject, <<-CRYSTAL
        unless a && !b
             # ^^^^^^^ error: Avoid negated conditions in `unless` blocks
          :nok
        end
        CRYSTAL

      expect_no_corrections source
    end

    it "fails if one of OR conditions is negated" do
      source = expect_issue subject, <<-CRYSTAL
        unless a || !b
             # ^^^^^^^ error: Avoid negated conditions in `unless` blocks
          :nok
        end
        CRYSTAL

      expect_no_corrections source
    end

    it "fails if one of inner conditions is negated" do
      source = expect_issue subject, <<-CRYSTAL
        unless a && (b || !c)
             # ^^^^^^^^^^^^^^ error: Avoid negated conditions in `unless` blocks
          :nok
        end
        CRYSTAL

      expect_no_corrections source
    end
  end
end
