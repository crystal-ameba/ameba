module Ameba::Formatter
  module Util
    def deansify(message : String?) : String?
      message.try &.gsub(/\x1b[^m]*m/, "").presence
    end

    def affected_code(source, location, end_location = nil, context_lines = 0, max_length = 100, placeholder = " ...", prompt = "> ")
      lines = source.lines
      lineno, column =
        location.line_number, location.column_number

      return unless affected_line = lines[lineno - 1]?.presence

      trim_line = Proc(String, String).new do |line|
        if line.size > max_length
          line = line[0, max_length - placeholder.size - 1] + placeholder
        end
        line
      end

      if column < max_length
        affected_line = trim_line.call(affected_line)
      end

      show_context = context_lines > 0
      if show_context
        pre_context, post_context = %w[], %w[]

        lines.each_with_index do |line, i|
          case i + 1
          when lineno - context_lines...lineno
            pre_context << trim_line.call(line)
          when lineno
            #
          when lineno + 1..lineno + context_lines
            post_context << trim_line.call(line)
          end
        end

        # remove empty lines at the beginning/end
        pre_context.shift? unless pre_context.first?.presence
        post_context.pop? unless post_context.last?.presence
      end

      String.build do |str|
        if show_context
          position = prompt.size + column
          position -= 1

          pre_context.try &.each do |line|
            str << prompt
            str.puts(line.colorize(:dark_gray))
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

          post_context.try &.each do |line|
            str << prompt
            str.puts(line.colorize(:dark_gray))
          end
        else
          stripped = affected_line.lstrip
          position = column - (affected_line.size - stripped.size) + prompt.size
          position -= 1

          str << prompt
          str.puts(stripped)

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
        end
      end
    end
  end
end
