# Parsed representation of code annotated with the `^^^ Message` style
class Ameba::SpecSupport::AnnotatedSource
  ANNOTATION_PATTERN = /\A\s*(\^+|\^{}) /
  ABBREV             = "[...]"

  getter lines : Array(String)

  # Each entry is the annotated line number and the annotation text.
  getter annotations : Array({Int32, String})

  # Separates annotation lines from code lines. Tracks the real
  # code line number that each annotation corresponds to.
  def self.parse(annotated_code)
    lines = [] of String
    annotations = [] of {Int32, String}
    annotated_code.each_line do |code_line|
      if ANNOTATION_PATTERN.matches?(code_line)
        annotations << {lines.size, code_line}
      else
        lines << code_line
      end
    end
    annotations.map! { |a| {1, a[1]} } if lines.empty?
    new(lines, annotations)
  end

  # NOTE: Annotations are sorted so that reconstructing the annotation
  #       text via `#to_s` is deterministic.
  def initialize(@lines, annotations)
    @annotations = annotations.sort
  end

  def ==(other)
    other.is_a?(AnnotatedSource) && other.lines == lines && match_annotations?(other)
  end

  private def match_annotations?(other)
    return false unless annotations.size == other.annotations.size

    annotations.zip(other.annotations) do |(actual_line, actual_annotation), (expected_line, expected_annotation)|
      return false unless actual_line == expected_line
      next if actual_annotation == expected_annotation
      return false unless expected_annotation.includes?(ABBREV)

      regex = Regex.new(annotation_to_regex(expected_annotation))
      return false unless actual_annotation.matches?(regex)
    end

    true
  end

  private def annotation_to_regex(expected_annotation)
    String.build do |io|
      io << '^'
      offset = 0
      while (index = expected_annotation.index(ABBREV, offset))
        io << Regex.escape(expected_annotation[offset...index])
        io << ".*?"
        offset += index
        offset += ABBREV.size
      end
      io << Regex.escape(expected_annotation[offset..])
      io << '$'
    end
  end

  # Constructs an annotated source string (like what we parse).
  #
  # Reconstructs a deterministic annotated source string. This is
  # useful for eliminating semantically irrelevant annotation
  # ordering differences.
  #
  #     source1 = AnnotatedSource.parse(<<-CRYSTAL)
  #     line1
  #     ^ Annotation 1
  #      ^^ Annotation 2
  #     CRYSTAL
  #
  #     source2 = AnnotatedSource.parse(<<-CRYSTAL)
  #     line1
  #      ^^ Annotation 2
  #     ^ Annotation 1
  #     CRYSTAL
  #
  #     source1.to_s == source2.to_s # => true
  def to_s(io)
    reconstructed = lines.dup
    annotations.reverse_each do |line_number, anno|
      reconstructed.insert(line_number, anno)
    end
    io << reconstructed.join('\n')
  end

  # Returns the plain source code without annotations.
  def plain_code
    lines.join('\n')
  end

  # Annotates the source code with the Ameba issues provided.
  def with_issue_annotations(issues)
    issue_annotations = [] of {Int32, String}
    issues.each do |issue|
      line, column, end_line, end_column = validate_location(issue)
      indent = " " * (column - 1)
      caret_count = column_length(line, column, end_line, end_column)
      carets = if caret_count.zero?
                 "^{}"
               else
                 "^" * caret_count
               end
      issue_annotations << {line, "#{indent}#{carets} #{issue.message}"}
    end
    AnnotatedSource.new(lines, issue_annotations)
  end

  private def validate_location(issue)
    loc, end_loc = issue.location, issue.end_location
    raise "Missing issue location: #{issue.message}" unless loc

    line, column = loc.line_number, loc.column_number
    raise "Invalid issue location: #{loc}" if column < 1 || line < 1

    if end_loc
      end_line, end_column = end_loc.line_number, end_loc.column_number
      if end_line < line || end_column < column
        raise <<-MSG
          Invalid issue start and end locations:
            #{loc}
            #{end_loc}
          MSG
      end
      if end_line < 1 || end_column < 1
        raise "Invalid issue end location: #{end_loc}"
      end
    end

    {line, column, end_line, end_column}
  end

  private def column_length(line, column, end_line, end_column)
    return 1 unless end_line && end_column

    if line < end_line
      code_line = lines[line - 1]
      end_column = code_line.size
    end

    end_column - column + 1
  end
end
