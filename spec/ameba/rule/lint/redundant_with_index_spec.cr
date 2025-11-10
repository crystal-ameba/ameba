require "../../../spec_helper"

module Ameba::Rule::Lint
  describe RedundantWithIndex do
    subject = RedundantWithIndex.new

    context "with_index" do
      it "does not report if there is index argument" do
        expect_no_issues subject, <<-CRYSTAL
          collection.each.with_index do |e, i|
            e += i
          end
          CRYSTAL
      end

      it "reports if there is no index argument" do
        expect_issue subject, <<-CRYSTAL
          collection.each.with_index do |e|
                        # ^^^^^^^^^^ error: Remove redundant `with_index`
            e += 1
          end
          CRYSTAL
      end

      it "reports if there is an underscored index argument" do
        expect_issue subject, <<-CRYSTAL
          collection.each.with_index do |e, _|
                        # ^^^^^^^^^^ error: Remove redundant `with_index`
            e += 1
          end
          CRYSTAL
      end

      it "reports if there is no args" do
        expect_issue subject, <<-CRYSTAL
          collection.each.with_index do
                        # ^^^^^^^^^^ error: Remove redundant `with_index`
            puts :nothing
          end
          CRYSTAL
      end

      it "does not report if there is no block" do
        expect_no_issues subject, <<-CRYSTAL
          collection.each.with_index
          CRYSTAL
      end

      it "does not report if first argument is underscored" do
        expect_no_issues subject, <<-CRYSTAL
          collection.each.with_index do |_, i|
            puts i
          end
          CRYSTAL
      end

      it "does not report if there are more than 2 args" do
        expect_no_issues subject, <<-CRYSTAL
          tup.each.with_index do |key, value, index|
            puts i
          end
          CRYSTAL
      end
    end

    context "each_with_index" do
      it "does not report if there is index argument" do
        expect_no_issues subject, <<-CRYSTAL
          collection.each_with_index do |e, i|
            e += i
          end
          CRYSTAL
      end

      it "reports if there is not index argument" do
        expect_issue subject, <<-CRYSTAL
          collection.each_with_index do |e|
                   # ^^^^^^^^^^^^^^^ error: Use `each` instead of `each_with_index`
            e += 1
          end
          CRYSTAL
      end

      it "reports if there is underscored index argument" do
        expect_issue subject, <<-CRYSTAL
          collection.each_with_index do |e, _|
                   # ^^^^^^^^^^^^^^^ error: Use `each` instead of `each_with_index`
            e += 1
          end
          CRYSTAL
      end

      it "reports if there is no args" do
        expect_issue subject, <<-CRYSTAL
          collection.each_with_index do
                   # ^^^^^^^^^^^^^^^ error: Use `each` instead of `each_with_index`
            puts :nothing
          end
          CRYSTAL
      end

      it "does not report if there is no block" do
        expect_no_issues subject, <<-CRYSTAL
          collection.each_with_index(1)
          CRYSTAL
      end

      it "does not report if first argument is underscored" do
        expect_no_issues subject, <<-CRYSTAL
          collection.each_with_index do |_, i|
            puts i
          end
          CRYSTAL
      end

      it "does not report if there are more than 2 args" do
        expect_no_issues subject, <<-CRYSTAL
          tup.each_with_index do |key, value, index|
            puts i
          end
          CRYSTAL
      end
    end
  end
end
