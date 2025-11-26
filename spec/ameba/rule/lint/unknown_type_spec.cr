require "../../../spec_helper"

module Ameba::Rule::Lint
  subject = UnknownType.new

  describe UnknownType do
    it "passes if types are known" do
      expect_no_issues subject, <<-'CRYSTAL', semantic: true
        a : Int32 = 1

        def hello(name : String)
          puts "Hello, #{name}!"
        end
        CRYSTAL
    end

    it "fails if types are unknown" do
      expect_issue subject, <<-CRYSTAL, semantic: true
        count : Int3 = 1
              # ^^^^ error: Unknown type
        def hello(name : Str)
                       # ^^^ error: Unknown type
          puts "Hello, #{name}!"
        end
        CRYSTAL
    end
  end
end
