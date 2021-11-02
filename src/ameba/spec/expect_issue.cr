require "./annotated_source"
require "./util"

# This mixin makes it easier to specify strict issue expectations
# in a declarative and visual fashion. Just type out the code that
# should generate an issue, annotate code by writing '^'s
# underneath each character that should be highlighted, and follow
# the carets with a string (separated by a space) that is the
# message of the issue. You can include multiple issues in
# one code snippet.
#
# Usage:
#
#     expect_issue subject, %(
#       def foo
#         a do
#           b
#         end.c
#       # ^^^^^ error: Avoid chaining a method call on a do...end block.
#       end
#     )
#
# Equivalent assertion without `expect_issue`:
#
#     source = Source.new %(
#       def foo
#         a do
#           b
#         end.c
#       end
#     ), "source.cr"
#     subject.catch(source).should_not be_valid
#     source.issues.size.should be(1)
#
#     issue = source.issues.first
#     issue.location.to_s.should eq "source.cr:4:3"
#     issue.end_location.to_s.should eq "source.cr:4:7"
#     issue.message.should eq(
#       "Avoid chaining a method call on a do...end block."
#     )
#
# If you do not want to specify an issue then use the
# companion method `expect_no_issues`. This method is a much
# simpler assertion since it just inspects the code and checks
# that there were no issues. The `expect_issue` method has
# to do more work by parsing out lines that contain carets.
module Ameba::Spec::ExpectIssue
  include Spec::Util

  def expect_issue(rules : Rule::Base | Enumerable(Rule::Base),
                   annotated_code : String,
                   path = "",
                   *,
                   file = __FILE__,
                   line = __LINE__,
                   **replacements)
    annotated_code = format_issue(annotated_code, **replacements)
    expected_annotations = AnnotatedSource.parse(annotated_code)
    lines = expected_annotations.lines
    code = lines.join('\n')

    if code == annotated_code
      raise "Use `report_no_issues` to assert that no issues are found"
    end

    source, actual_annotations = actual_annotations(rules, code, path, lines)
    unless actual_annotations == expected_annotations
      fail <<-MSG, file, line
        Expected:

        #{expected_annotations}

        Got:

        #{actual_annotations}
        MSG
    end

    source
  end

  def expect_correction(source, correction, *, file = __FILE__, line = __LINE__)
    raise "Use `expect_no_corrections` if the code will not change" unless source.correct
    return if correction == source.code

    fail <<-MSG, file, line
      Expected correction:

      #{correction}

      Got:

      #{source.code}
      MSG
  end

  def expect_no_corrections(source, *, file = __FILE__, line = __LINE__)
    return unless source.correct

    fail <<-MSG, file, line
      Expected no corrections, but got:

      #{source.code}
      MSG
  end

  def expect_no_issues(rules : Rule::Base | Enumerable(Rule::Base),
                       code : String,
                       path = "",
                       *,
                       file = __FILE__,
                       line = __LINE__)
    lines = code.split('\n') # must preserve trailing newline
    _, actual_annotations = actual_annotations(rules, code, path, lines)
    unless actual_annotations.to_s == code
      fail <<-MSG, file, line
        Expected no issues, but got:

        #{actual_annotations}
        MSG
    end
  end

  private def actual_annotations(rules, code, path, lines)
    source = Source.new(code, path, normalize: false)
    if rules.is_a?(Enumerable)
      rules.each(&.catch(source))
    else
      rules.catch(source)
    end
    {source, AnnotatedSource.new(lines, source.issues)}
  end

  private def format_issue(code, **replacements)
    replacements.each do |keyword, value|
      value = value.to_s
      code = code.gsub("%{#{keyword}}", value)
      code = code.gsub("^{#{keyword}}", "^" * value.size)
      code = code.gsub("_{#{keyword}}", " " * value.size)
    end
    code
  end
end
