require "../../../spec_helper"

module Ameba::Rule::Naming
  subject = PredicateName.new

  describe PredicateName do
    it "passes if predicate name is correct" do
      expect_no_issues subject, <<-CRYSTAL
        def valid?(x)
        end

        class Image
          def picture?(x)
          end
        end

        def allow_this_picture?
        end
        CRYSTAL
    end

    it "fails if predicate name is wrong" do
      expect_issue subject, <<-CRYSTAL
        class Image
          def self.is_valid?(x)
                 # ^^^^^^^^^ error: Favour method name 'valid?' over 'is_valid?'
          end
        end

        def is_valid?(x)
          # ^^^^^^^^^ error: Favour method name 'valid?' over 'is_valid?'
        end

        def is_valid(x)
          # ^^^^^^^^ error: Favour method name 'valid?' over 'is_valid'
        end
        CRYSTAL
    end

    it "ignores if alternative name isn't valid syntax" do
      expect_no_issues subject, <<-CRYSTAL
        class Image
          def is_404?(x)
            true
          end
        end
        CRYSTAL
    end
  end
end
