require "../../../spec_helper"

module Ameba::Rule::Lint
  describe InvalidParameterName do
    subject = InvalidParameterName.new

    it "passes for valid method parameter names" do
      expect_no_issues subject, <<-CRYSTAL
        def foo(bar, baz)
          bar + baz
        end

        def foo(bar : Int32 = 1, baz : String? = nil)
          bar
        end

        def foo(*args, **options, &block)
          yield
        end

        def foo(active? active, valid! valid)
          active && valid
        end

        def foo(_bar)
        end
        CRYSTAL
    end

    it "passes for valid macro parameter names" do
      expect_no_issues subject, <<-CRYSTAL
        macro foo(bar, baz)
          {{ bar }} + {{ baz }}
        end

        macro foo(*args, **options, &block)
          {{ yield }}
        end
        CRYSTAL
    end

    it "passes for valid block parameter names" do
      expect_no_issues subject, <<-CRYSTAL
        items.each { |item| item }

        items.each do |item|
          item
        end

        items.each do |*args|
          args
        end

        items.each do |(key, value)|
          key
        end

        items.each do |_|
        end
        CRYSTAL
    end

    it "passes for proc literal parameters" do
      expect_no_issues subject, <<-CRYSTAL
        ->(bar? : Int32) { bar? }
        CRYSTAL
    end

    it "reports method parameters ending with `?` or `!`" do
      expect_issue subject, <<-CRYSTAL
        def foo(bar?)
              # ^^^^ error: Invalid parameter name `bar?`
        end

        def foo(bar!)
              # ^^^^ error: Invalid parameter name `bar!`
        end
        CRYSTAL
    end

    it "reports multiple invalid method parameters" do
      expect_issue subject, <<-CRYSTAL
        def foo(foo, bar?, baz!)
                   # ^^^^ error: Invalid parameter name `bar?`
                         # ^^^^ error: Invalid parameter name `baz!`
        end
        CRYSTAL
    end

    it "reports splat, double splat, and block method parameters ending with `?` or `!`" do
      expect_issue subject, <<-CRYSTAL
        def foo(*bar?, **baz!, &block?)
               # ^^^^ error: Invalid parameter name `bar?`
                       # ^^^^ error: Invalid parameter name `baz!`
                              # ^^^^^^ error: Invalid parameter name `block?`
        end
        CRYSTAL
    end

    it "reports method parameter where internal name ends with `?` or `!`" do
      expect_issue subject, <<-CRYSTAL
        def foo(baz bar?)
              # ^^^^ error: Invalid parameter name `bar?`
        end
        CRYSTAL
    end

    it "reports macro parameters ending with `?` or `!`" do
      expect_issue subject, <<-CRYSTAL
        macro foo(bar?)
                # ^^^^ error: Invalid parameter name `bar?`
        end

        macro foo(bar!)
                # ^^^^ error: Invalid parameter name `bar!`
        end

        macro foo(*bar?, **baz!, &block?)
                 # ^^^^ error: Invalid parameter name `bar?`
                         # ^^^^ error: Invalid parameter name `baz!`
                                # ^^^^^^ error: Invalid parameter name `block?`
        end
        CRYSTAL
    end

    it "reports block parameters ending with `?` or `!`" do
      expect_issue subject, <<-CRYSTAL
        items.each { |bar?| bar? }
                    # ^^^^ error: Invalid parameter name `bar?`

        items.each do |bar!|
                     # ^^^^ error: Invalid parameter name `bar!`
        end

        items.each do |*bar?|
                      # ^^^^ error: Invalid parameter name `bar?`
        end
        CRYSTAL
    end

    it "reports unpacked block parameters ending with `?` or `!`" do
      expect_issue subject, <<-CRYSTAL
        items.each do |(foo, bar?)|
                           # ^^^^ error: Invalid parameter name `bar?`
        end
        CRYSTAL
    end

    it "reports nested unpacked block parameters ending with `?` or `!`" do
      expect_issue subject, <<-CRYSTAL
        items.each do |((foo, bar?), baz!)|
                            # ^^^^ error: Invalid parameter name `bar?`
                                   # ^^^^ error: Invalid parameter name `baz!`
        end
        CRYSTAL
    end

    it "reports method parameters with type restrictions and default values" do
      expect_issue subject, <<-CRYSTAL
        def foo(bar? : Int32 = 42, baz! : String? = nil)
              # ^^^^ error: Invalid parameter name `bar?`
                                 # ^^^^ error: Invalid parameter name `baz!`
        end
        CRYSTAL
    end

    it "reports multiline method parameters" do
      expect_issue subject, <<-CRYSTAL
        def foo(
          foo,
          bar?,
        # ^^^^ error: Invalid parameter name `bar?`
          baz!
        # ^^^^ error: Invalid parameter name `baz!`
        )
        end
        CRYSTAL
    end
  end
end
