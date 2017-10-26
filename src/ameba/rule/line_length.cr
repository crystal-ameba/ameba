struct Ameba::Rule::LineLength
  def test(source)
    source.lines.each do |line|
      if line.size > 79
        source.errors << "Line too long"
      end
    end
  end
end
