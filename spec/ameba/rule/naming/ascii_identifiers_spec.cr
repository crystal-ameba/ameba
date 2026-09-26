require "../../../spec_helper"

module Ameba::Rule::Naming
  describe AsciiIdentifiers do
    subject = AsciiIdentifiers.new

    it "reports classes with names containing non-ascii characters" do
      expect_issue subject, <<-CRYSTAL
        class BigAwesome🐺
            # ^^^^^^^^^^^ error: Identifier contains non-ascii characters
          @🐺_name : String
        # ^^^^^^^ error: Identifier contains non-ascii characters
        end
        CRYSTAL
    end

    it "reports modules with names containing non-ascii characters" do
      expect_issue subject, <<-CRYSTAL
        module Bąk
             # ^^^ error: Identifier contains non-ascii characters
          @@bąk_name : String
        # ^^^^^^^^^^ error: Identifier contains non-ascii characters
        end
        CRYSTAL
    end

    it "reports enums with names containing non-ascii characters" do
      expect_issue subject, <<-CRYSTAL
        enum TypeOf🔥
           # ^^^^^^^ error: Identifier contains non-ascii characters
        end
        CRYSTAL
    end

    it "reports defs with names containing non-ascii characters" do
      expect_issue subject, <<-CRYSTAL
        def łódź
          # ^^^^ error: Identifier contains non-ascii characters
        end
        CRYSTAL
    end

    it "reports defs with parameter names containing non-ascii characters" do
      expect_issue subject, <<-CRYSTAL
        def forest_adventure(include_🐺 = true, include_🐿 = true)
                           # ^^^^^^^^^ error: Identifier contains non-ascii characters
                                             # ^^^^^^^^^ error: Identifier contains non-ascii characters
        end
        CRYSTAL
    end

    it "reports defs with parameter default values containing non-ascii characters" do
      expect_issue subject, <<-CRYSTAL
        def forest_adventure(animal_type = :🐺)
                                         # ^^ error: Identifier contains non-ascii characters
        end
        CRYSTAL
    end

    it "reports argument names containing non-ascii characters" do
      expect_issue subject, <<-CRYSTAL
        %w[wensleydale cheddar brie].each { |🧀| nil }
                                           # ^ error: Identifier contains non-ascii characters
        CRYSTAL
    end

    it "reports calls with arguments containing non-ascii characters" do
      expect_issue subject, <<-CRYSTAL
        %i[🐺 🐿].index!(:🐺)
                     # ^^ error: Identifier contains non-ascii characters
        CRYSTAL
    end

    it "reports calls with named arguments containing non-ascii characters" do
      expect_issue subject, <<-CRYSTAL
        %i[🐺 🐿].index!(obj: :🐺)
                          # ^^ error: Identifier contains non-ascii characters
        CRYSTAL
    end

    it "reports aliases with names containing non-ascii characters" do
      expect_issue subject, <<-CRYSTAL
        alias JSON🧀 = JSON::Any
            # ^^^^^ error: Identifier contains non-ascii characters
        CRYSTAL
    end

    it "reports constants with names containing non-ascii characters" do
      expect_issue subject, <<-CRYSTAL
        I_LOVE_🍣 = true
        # ^^^^^^ error: Identifier contains non-ascii characters
        CRYSTAL
    end

    it "reports assignments with variable names containing non-ascii characters" do
      expect_issue subject, <<-CRYSTAL
        space_👾 = true
        # ^^^^^ error: Identifier contains non-ascii characters
        CRYSTAL
    end

    it "reports multiple assignments with variable names containing non-ascii characters" do
      expect_issue subject, <<-CRYSTAL
        foo, space_👾 = true, true
           # ^^^^^^^ error: Identifier contains non-ascii characters
        CRYSTAL
    end

    it "reports assignments with symbol literals containing non-ascii characters" do
      expect_issue subject, <<-CRYSTAL
        foo = :신장
            # ^^^ error: Identifier contains non-ascii characters
        CRYSTAL
    end

    it "reports multiple assignments with symbol literals containing non-ascii characters" do
      expect_issue subject, <<-CRYSTAL
        foo, bar = :신장, true
                 # ^^^ error: Identifier contains non-ascii characters
        CRYSTAL
    end

    it "passes for strings with non-ascii characters" do
      expect_no_issues subject, <<-CRYSTAL
        space = "👾"
        space = :invader # 👾
        CRYSTAL
    end

    context "properties" do
      context "#ignore_symbols" do
        it "returns `false` by default" do
          rule = subject.class.new
          rule.ignore_symbols?.should be_false
        end

        it "stops reporting symbol literals if set to `true`" do
          rule = subject.class.new
          rule.ignore_symbols = true

          expect_no_issues rule, <<-CRYSTAL
            def forest_adventure(animal_type = :🐺); end
            %i[🐺 🐿].index!(:🐺)
            foo, bar = :신장, true
            foo = :신장
            CRYSTAL
        end
      end
    end
  end
end
