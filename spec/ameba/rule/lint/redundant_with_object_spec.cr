require "../../../spec_helper"

module Ameba::Rule::Lint
  describe RedundantWithObject do
    subject = RedundantWithObject.new

    it "does not report if there is index argument" do
      expect_no_issues subject, <<-CRYSTAL
        collection.each_with_object(0) do |e, obj|
          obj += i
        end
        CRYSTAL
    end

    it "reports if there is not index argument" do
      expect_issue subject, <<-CRYSTAL
        collection.each_with_object(0) do |e|
                 # ^^^^^^^^^^^^^^^^ error: Use `each` instead of `each_with_object`
          e += 1
        end
        CRYSTAL
    end

    it "reports if there is underscored index argument" do
      expect_issue subject, <<-CRYSTAL
        collection.each_with_object(0) do |e, _|
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
        tup.each_with_object(0) do |key, value, obj|
          puts i
        end
        CRYSTAL
    end
  end
end
