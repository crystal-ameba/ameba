struct Ameba::Rule::LineLength
  def test(source)
    source.lines.each_with_index do |line, index|
      if line.size > 79
        source.error self, index + 1, "Line too long [#{line.size}]"
      end
    end
  end
end
