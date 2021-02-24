module Ameba::Formatter
  module Util
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

    def affected_code(source, location, end_location = nil, context_lines = 0, max_length = 120, ellipsis = " ...", prompt = "> ")
      lines = source.lines
      lineno, column =
        location.line_number, location.column_number

      return unless affected_line = lines[lineno - 1]?.presence

      if column < max_length
        affected_line = trim(affected_line, max_length, ellipsis)
      end

      show_context = context_lines > 0

      if show_context
        pre_context, post_context =
          context(lines, lineno, context_lines)

        position = prompt.size + column
        position -= 1
      else
        affected_line_size, affected_line =
          affected_line.size, affected_line.lstrip

        position = column - (affected_line_size - affected_line.size) + prompt.size
        position -= 1
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
