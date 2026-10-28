require "../../../spec_helper"

module Ameba::Rule::Lint
  describe ComparisonToBoolean do
    subject = ComparisonToBoolean.new

    it "passes if there is no comparison to boolean" do
      expect_no_issues subject, <<-CRYSTAL
        a = true

        if a
          :ok
        end

        if true
          :ok
        end

        unless s.empty?
          :ok
        end

        :ok if a
        :ok if a != 1
        :ok if a == "true"

        case a
        when true
          :ok
        when false
          :not_ok
        end
        CRYSTAL
    end

    context "boolean on the right" do
      it "fails if there is == comparison to boolean" do
        source = expect_issue subject, <<-CRYSTAL
          if s.empty? == true
           # ^^^^^^^^^^^^^^^^ error: Comparison to a boolean is pointless
            :ok
          end

          if s.empty? == false
           # ^^^^^^^^^^^^^^^^^ error: Comparison to a boolean is pointless
            :ok
          end
          CRYSTAL

        expect_no_corrections source
      end

      it "fails if there is != comparison to boolean" do
        source = expect_issue subject, <<-CRYSTAL
          if a != false
           # ^^^^^^^^^^ error: Comparison to a boolean is pointless
            :ok
          end

          if a != true
           # ^^^^^^^^^ error: Comparison to a boolean is pointless
            :ok
          end
          CRYSTAL

        expect_no_corrections source
      end

      it "fails if there is case comparison to boolean" do
        source = expect_issue subject, <<-CRYSTAL
          a === true
          # ^^^^^^^^ error: Comparison to a boolean is pointless
          CRYSTAL

        expect_no_corrections source
      end
    end

    context "boolean on the left" do
      it "fails if there is == comparison to boolean" do
        source = expect_issue subject, <<-CRYSTAL
          if true == s.empty?
           # ^^^^^^^^^^^^^^^^ error: Comparison to a boolean is pointless
            :ok
          end

          if false == s.empty?
           # ^^^^^^^^^^^^^^^^^ error: Comparison to a boolean is pointless
            :ok
          end
          CRYSTAL

        expect_no_corrections source
      end

      it "fails if there is != comparison to boolean" do
        source = expect_issue subject, <<-CRYSTAL
          if false != a
           # ^^^^^^^^^^ error: Comparison to a boolean is pointless
            :ok
          end

          if true != a
           # ^^^^^^^^^ error: Comparison to a boolean is pointless
            :ok
          end
          CRYSTAL

        expect_no_corrections source
      end

      it "fails if there is case comparison to boolean" do
        source = expect_issue subject, <<-CRYSTAL
          true === a
          # ^^^^^^^^ error: Comparison to a boolean is pointless
          CRYSTAL

        expect_no_corrections source
      end
    end
  end
end
