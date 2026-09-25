require "../../../spec_helper"

module Ameba::Rule::Lint
  describe RedundantWithObject do
    subject = RedundantWithObject.new

    context "with_object" do
      it "does not report if there is object argument" do
        expect_no_issues subject, <<-CRYSTAL
          collection.each.with_object(0) do |e, obj|
            e += i
          end
          CRYSTAL
      end

      it "reports if there is no object argument" do
        expect_issue subject, <<-CRYSTAL
          collection.each.with_object(0) do |e|
                        # ^^^^^^^^^^^ error: Remove redundant `with_object`
            e += 1
          end
          CRYSTAL
      end

      it "reports if there is an underscored object argument" do
        expect_issue subject, <<-CRYSTAL
          collection.each.with_object(0) do |e, _|
                        # ^^^^^^^^^^^ error: Remove redundant `with_object`
            e += 1
          end
          CRYSTAL
      end

      it "reports if there is an underscored object argument (2)" do
        expect_issue subject, <<-CRYSTAL
          collection.each.with_object(0) do |e, _obj|
                        # ^^^^^^^^^^^ error: Remove redundant `with_object`
            e += 1
          end
          CRYSTAL
      end

      it "reports if there is no args" do
        expect_issue subject, <<-CRYSTAL
          collection.each.with_object do
                        # ^^^^^^^^^^^ error: Remove redundant `with_object`
            puts :nothing
          end
          CRYSTAL
      end

      it "does not report if there is no block" do
        expect_no_issues subject, <<-CRYSTAL
          collection.each.with_object(0)
          CRYSTAL
      end

      it "does not report if first argument is underscored" do
        expect_no_issues subject, <<-CRYSTAL
          collection.each.with_object(0) do |_, obj|
            puts i
          end
          CRYSTAL
      end

      it "does not report if there are more than 2 args" do
        expect_no_issues subject, <<-CRYSTAL
          tup.each.with_object(0) do |key, value, object|
            puts i
          end
          CRYSTAL
      end
    end

    context "each_with_object" do
      it "does not report if there is object argument" do
        expect_no_issues subject, <<-CRYSTAL
          collection.each_with_object(0) do |e, obj|
            obj += i
          end
          CRYSTAL
      end

      it "reports if there is no object argument" do
        expect_issue subject, <<-CRYSTAL
          collection.each_with_object(0) do |e|
                   # ^^^^^^^^^^^^^^^^ error: Use `each` instead of `each_with_object`
            e += 1
          end
          CRYSTAL
      end

      it "reports if there is underscored object argument" do
        expect_issue subject, <<-CRYSTAL
          collection.each_with_object(0) do |e, _|
                   # ^^^^^^^^^^^^^^^^ error: Use `each` instead of `each_with_object`
            e += 1
          end
          CRYSTAL
      end

      it "reports if there is underscored object argument (2)" do
        expect_issue subject, <<-CRYSTAL
          collection.each_with_object(0) do |e, _obj|
                   # ^^^^^^^^^^^^^^^^ error: Use `each` instead of `each_with_object`
            e += 1
          end
          CRYSTAL
      end

      it "reports if there is no args" do
        expect_issue subject, <<-CRYSTAL
          collection.each_with_object(0) do
                   # ^^^^^^^^^^^^^^^^ error: Use `each` instead of `each_with_object`
            puts :nothing
          end
          CRYSTAL
      end

      it "does not report if there is no block" do
        expect_no_issues subject, <<-CRYSTAL
          collection.each_with_object(0)
          CRYSTAL
      end

      it "does not report if first argument is underscored" do
        expect_no_issues subject, <<-CRYSTAL
          collection.each_with_object(0) do |_, obj|
            puts i
          end
          CRYSTAL
      end

      it "does not report if there are more than 2 args" do
        expect_no_issues subject, <<-CRYSTAL
          tuple.each_with_object(0) do |key, value, obj|
            puts i
          end
          CRYSTAL
      end
    end
  end
end
