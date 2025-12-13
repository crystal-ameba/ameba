require "./ameba"

DOCS_FILEPATH =
  Path[__DIR__, "..", "reference"].expand

private def markdownify(rule) : String?
  return unless doc = rule.parsed_doc

  content = "# `%s`\n\n%s" % {rule.rule_name, doc}
  content
    .sub(
      /YAML configuration example:(\n\n```)\n/,
      "## YAML configuration example\\1yaml\n",
    )
    .gsub(
      /(^|\n```)\n(?!>$|\n)/,
      "\\1crystal\n",
    )
end

Ameba::Rule.rules.each do |rule|
  next unless content = markdownify(rule)

  path =
    DOCS_FILEPATH / ("%s.md" % rule.rule_name)

  Dir.mkdir_p(path.parent)

  File.open(path, "w") do |file|
    file.puts(content)
  end
end
