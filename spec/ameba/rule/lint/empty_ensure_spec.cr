require "../../../spec_helper"

module Ameba::Rule::Lint
  describe EmptyEnsure do
    subject = EmptyEnsure.new

    it "passes if there is no empty ensure blocks" do
      expect_no_issues subject, <<-CRYSTAL
        def some_method
          do_some_stuff
        ensure
          do_something_else
        end

        begin
          do_some_stuff
        ensure
          do_something_else
        end

        def method_with_rescue
        rescue
        ensure
          nil
        end
      CRYSTAL
    end

    it "fails if there is an empty ensure in method" do
      expect_issue subject, <<-CRYSTAL
        def method
          do_some_stuff
        ensure
      # ^^^^^^ error: Empty `ensure` block detected
        end
      CRYSTAL
    end

    it "fails if there is an empty ensure in a block" do
      expect_issue subject, <<-CRYSTAL
        begin
          do_some_stuff
        rescue
          do_some_other_stuff
        ensure
      # ^^^^^^ error: Empty `ensure` block detected
          # nothing here
        end
      CRYSTAL
    end
  end
end
