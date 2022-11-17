require "../../../spec_helper"

LITERAL_SAMPLES = {
  nil, true, 42, 4.2, 'c', "foo", :foo, /foo/,
  0..42, [1, 2, 3], {1, 2, 3},
  {foo: :bar}, {:foo => :bar},
}

module Ameba::Rule::Lint
  subject = LiteralAssignmentsInExpressions.new

  describe LiteralAssignmentsInExpressions do
    it "passes if the assignment value is not a literal" do
      expect_no_issues subject, <<-CRYSTAL
        if a = b
          :ok
        end

        unless a = b.presence
          :ok
        end

        :ok if a = b
        :ok unless a = b

        case {a, b}
        when {0, 1} then :gt
        when {1, 0} then :lt
        end
        CRYSTAL
    end

    {% for literal in LITERAL_SAMPLES %}
      it %(reports if the assignment value is a {{ literal }} literal) do
        expect_issue subject, <<-CRYSTAL, literal: {{ literal.stringify }}
          raise "boo!" if foo = {{ literal }}
                        # ^{literal}^^^^^^ error: Detected assignment with a literal value in control expression
          CRYSTAL

        expect_issue subject, <<-CRYSTAL, literal: {{ literal.stringify }}
          raise "boo!" unless foo = {{ literal }}
                            # ^{literal}^^^^^^ error: Detected assignment with a literal value in control expression
          CRYSTAL
      end
    {% end %}
  end
end
