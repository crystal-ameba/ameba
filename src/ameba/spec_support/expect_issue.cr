require "./annotated_source"
require "./util"

# This mixin makes it easier to specify strict issue expectations
# in a declarative and visual fashion. Just type out the code that
# should generate a issue, annotate code by writing '^'s
# underneath each character that should be highlighted, and follow
# the carets with a string (separated by a space) that is the
# message of the issue. You can include multiple issues in
# one code snippet.
#
# Usage:
#
#     expect_issue subject, %(
#       a do
#         b
#       end.c
#       ^^^^^ Avoid chaining a method call on a do...end block.
#     )
#
# Equivalent assertion without `expect_issue`:
#
#     source = Source.new %(
#       a do
#         b
#       end.c
#     ), "source.cr"
#     subject.catch(source).should_not be_valid
#     source.issues.size.should be(1)
#
#     issue = source.issues.first
#     issue.location.to_s.should eq "source.cr:3:1"
#     issue.end_location.to_s.should eq "source.cr:3:5"
#     issue.message.should eq(
#       "Avoid chaining a method call on a do...end block."
#     )
#
# If you do not want to specify an issue then use the
# companion method `expect_no_issues`. This method is a much
# simpler assertion since it just inspects the code and checks
# that there were no issues. The `expect_issue` method has
# to do more work by parsing out lines that contain carets.
module Ameba::SpecSupport::ExpectIssue
  include Ameba::SpecSupport::Util

  def expect_issue(rules : Rule::Base | Array(Rule::Base),
                   annotated_code : String,
                   path = "",
                   normalize = true,
                   *,
                   file = __FILE__,
                   line = __LINE__)
    annotated_code, expected_annotations = parse_annotations(annotated_code, normalize)
    plain_code = check_for_annotations(annotated_code, expected_annotations.plain_code)
    actual_annotations = actual_annotations(rules, plain_code, path, expected_annotations)
    if actual_annotations != expected_annotations
      fail <<-MSG, file, line
        Expected:

        #{expected_annotations}

        Got:

        #{actual_annotations}
        MSG
    end
  end

  def expect_no_issues(rules : Rule::Base | Array(Rule::Base),
                       code : String,
                       path = "",
                       normalize = true,
                       *,
                       file = __FILE__,
                       line = __LINE__)
    code, expected_annotations = parse_annotations(code, normalize)
    actual_annotations = actual_annotations(rules, code, path, expected_annotations)
    if actual_annotations.to_s != code
      fail <<-MSG, file, line
        Expected no issues, but got:

        #{actual_annotations}
        MSG
    end
  end

  private def parse_annotations(annotated_code, normalize)
    annotated_code = normalize_code(annotated_code) if normalize
    expected_annotations = AnnotatedSource.parse(annotated_code)
    {annotated_code, expected_annotations}
  end

  private def actual_annotations(rules, plain_code, path, expected_annotations)
    source = Source.new(plain_code, path)
    if rules.is_a?(Array)
      rules.each(&.catch(source))
    else
      rules.catch(source)
    end
    expected_annotations.with_issue_annotations(source.issues)
  end

  private def check_for_annotations(annotated_code, plain_code)
    if plain_code == annotated_code
      raise "Use `report_no_issues` to assert that no issues are found"
    end
    plain_code.chomp
  end
end
