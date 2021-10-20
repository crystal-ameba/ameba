module Ameba::SpecSupport::Util
  def normalize_code(code, separator = "\n")
    lines = code.split(separator)

    # remove unneeded first blank lines if any
    lines.shift if lines[0].blank? && lines.size > 1

    # find the minimum indentation
    min_indent = lines.min_of do |line|
      line.blank? ? code.size : line.size - line.lstrip.size
    end

    # remove the width of minimum indentation in each line
    lines
      .map! { |line| line.blank? ? line : line[min_indent..-1] }
      .join(separator)
  end
end
