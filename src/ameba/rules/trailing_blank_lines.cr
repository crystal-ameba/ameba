# A rule that disallows trailing blank lines at the end of the source file.

Ameba.rule TrailingBlankLines do |source|
  if source.lines.size > 1 && source.lines[-2, 2].join.strip.empty?
    source.error self, source.lines.size,
      "Blank lines detected at the end of the file"
  end
end
