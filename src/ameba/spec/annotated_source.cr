# Parsed representation of code annotated with the `# ^^^ error: Message` style
class Ameba::Spec::AnnotatedSource
  ANNOTATION_PATTERN_1 = /\A\s*(# )?(\^+|\^{})( error:)? /
  ANNOTATION_PATTERN_2 = " # error: "

  ABBREV = "[...]"

  getter lines : Array(String)

  # Each entry is the line number, annotation prefix, and message.
  # The prefix is empty if the annotation is at the end of a code line.
  getter annotations : Array({Int32, String, String})

  # Separates annotation lines from code lines. Tracks the real
  # code line number that each annotation corresponds to.
  def self.parse(annotated_code)
    lines = [] of String
    annotations = [] of {Int32, String, String}

    code_lines = annotated_code.split('\n') # must preserve trailing newline
    code_lines.each do |code_line|
      case
      when annotation_match = ANNOTATION_PATTERN_1.match(code_line)
        message_index = annotation_match.end
        prefix = code_line[0...message_index]
        message = code_line[message_index...]
        annotations << {lines.size, prefix, message}
      when annotation_index = code_line.index(ANNOTATION_PATTERN_2)
        lines << code_line[...annotation_index]
        message_index = annotation_index + ANNOTATION_PATTERN_2.size
        message = code_line[message_index...]
        annotations << {lines.size, "", message}
      else
        lines << code_line
      end
    end
    annotations.map! { |_, prefix, message| {1, prefix, message} } if lines.empty?
    new(lines, annotations)
  end

  # NOTE: Annotations are sorted so that reconstructing the annotation
  #       text via `#to_s` is deterministic.
  def initialize(@lines, annotations : Enumerable({Int32, String, String}))
    @annotations = annotations.to_a.sort_by do |line, _, message|
      {line, message}
    end
  end

  # Annotates the source code with the Ameba issues provided.
  #
  # NOTE: Annotations are sorted so that reconstructing the annotation
  #       text via `#to_s` is deterministic.
  def initialize(@lines, issues : Enumerable(Issue))
    @annotations = issues_to_annotations(issues).sort_by do |line, _, message|
      {line, message}
    end
  end

  def ==(other)
    other.is_a?(AnnotatedSource) && other.lines == lines && match_annotations?(other)
  end

  private def match_annotations?(other)
    return false unless annotations.size == other.annotations.size

    annotations.zip(other.annotations) do |(actual_line, actual_prefix, actual_message), (expected_line, expected_prefix, expected_message)|
      return false unless actual_line == expected_line
      return false unless expected_prefix.empty? || actual_prefix == expected_prefix
      next if actual_message == expected_message
      return false unless expected_message.includes?(ABBREV)

      regex = /\A#{message_to_regex(expected_message)}\Z/
      return false unless actual_message.matches?(regex)
    end

    true
  end

  private def message_to_regex(expected_annotation)
    String.build do |io|
      offset = 0
      while index = expected_annotation.index(ABBREV, offset)
        io << Regex.escape(expected_annotation[offset...index])
        io << ".*?"
        offset = index + ABBREV.size
      end
      io << Regex.escape(expected_annotation[offset..])
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
    annotations.reverse_each do |line_number, prefix, message|
      if prefix.empty?
        reconstructed[line_number - 1] += "#{ANNOTATION_PATTERN_2}#{message}"
      else
        line_number = 0 if lines.empty?
        reconstructed.insert(line_number, "#{prefix}#{message}")
      end
    end
    io << reconstructed.join('\n')
  end

  private def issues_to_annotations(issues)
    issues.map do |issue|
      line, column, end_line, end_column = validate_location(issue)
      indent_count = column - 3
      indent = if indent_count < 0
                 ""
               else
                 " " * indent_count
               end
      caret_count = column_length(line, column, end_line, end_column)
      caret_count += indent_count if indent_count < 0
      carets = if caret_count <= 0
                 "^{}"
               else
                 "^" * caret_count
               end
      {line, "#{indent}# #{carets} error: ", issue.message}
    end
  end

  private def validate_location(issue)
    loc, end_loc = issue.location, issue.end_location
    raise "Missing location for issue '#{issue.message}'" unless loc

    line, column = loc.line_number, loc.column_number
    if line > lines.size || line < 1 || column < 1
      raise "Invalid issue location: #{loc}"
    end

    if end_loc
      if end_loc < loc
        raise <<-MSG
          Invalid issue location
            start: #{loc}
            end:   #{end_loc}
          MSG
      end

      end_line, end_column = end_loc.line_number, end_loc.column_number

      if end_line > lines.size || end_line < 1 || end_column < 1
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
