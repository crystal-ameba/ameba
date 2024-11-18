module Ameba::Formatter
  module Util
    extend self

    def deansify(message : String?) : String?
      message.try &.gsub(/\x1b[^m]*m/, "").presence
    end

    def trim(str, max_length = 120, ellipsis = " ...")
      if (str.size - ellipsis.size) > max_length
        str = str[0, max_length]
        if str.size > ellipsis.size
          str = str[0...-ellipsis.size] + ellipsis
        end
      end
      str
    end

    def context(lines, lineno, context_lines = 3, remove_empty = true)
      pre_context, post_context = %w[], %w[]

      lines.each_with_index do |line, i|
        case i + 1
        when lineno - context_lines...lineno
          pre_context << line
        when lineno + 1..lineno + context_lines
          post_context << line
        end
      end

      if remove_empty
        # remove empty lines at the beginning ...
        while pre_context.first?.try(&.blank?)
          pre_context.shift
        end
        # ... and the end
        while post_context.last?.try(&.blank?)
          post_context.pop
        end
      end

      {pre_context, post_context}
    end

    def affected_code(issue : Issue, context_lines = 0, max_length = 120, ellipsis = " ...", prompt = "> ")
      return unless location = issue.location

      affected_code(issue.code, location, issue.end_location, context_lines, max_length, ellipsis, prompt)
    end

    def affected_code(code, location, end_location = nil, context_lines = 0, max_length = 120, ellipsis = " ...", prompt = "> ")
      lines = code.split('\n') # must preserve trailing newline
      lineno, column =
        location.line_number, location.column_number

      return unless affected_line = lines[lineno - 1]?.presence

      if column < max_length
        affected_line = trim(affected_line, max_length, ellipsis)
      end

      position = prompt.size + column
      position -= 1

      show_context = context_lines > 0

      if show_context
        pre_context, post_context =
          context(lines, lineno, context_lines)
      else
        affected_line_size, affected_line =
          affected_line.size, affected_line.lstrip

        indent_size_diff = affected_line_size - affected_line.size
        if column > indent_size_diff
          position -= indent_size_diff
        end
      end

      String.build do |str|
        if show_context
          pre_context.try &.each do |line|
            line = trim(line, max_length, ellipsis)
            str << prompt
            str.puts(line.colorize(:dark_gray))
          end
        end

        str << prompt
        str.puts(affected_line.colorize(:white))

        str << (" " * position)
        str << "^".colorize(:yellow)

        if end_location
          end_lineno = end_location.line_number
          end_column = end_location.column_number

          if end_lineno == lineno && end_column > column
            end_position = end_column - column
            end_position -= 1

            str << ("-" * end_position).colorize(:dark_gray)
            str << "^".colorize(:yellow)
          end
        end

        str.puts

        if show_context
          post_context.try &.each do |line|
            line = trim(line, max_length, ellipsis)
            str << prompt
            str.puts(line.colorize(:dark_gray))
          end
        end
      end
    end
  end
end
