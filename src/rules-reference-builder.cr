require "file_utils"
require "./ameba"

module Ameba::Reference
  module Builder
    extend self

    def build(outdir : Path) : Nil
      FileUtils.rm_rf(outdir)

      Rule.rules.each do |rule|
        build(rule, outdir)
      end
    end

    def build(rule : Rule::Base.class, outdir : Path) : Nil
      return unless content = markdownify(rule)

      path =
        outdir / "#{rule.rule_name}.md"

      Dir.mkdir_p(path.parent)

      File.open(path, "w") do |file|
        file.puts(content)
      end
    end

    private def markdownify(rule : Rule::Base.class) : String?
      return unless doc = rule.parsed_doc

      content = "# `%s`\n\n%s" % {rule.rule_name, doc}
      content
        .sub(
          /YAML configuration example:(\n\n```)\n/,
          "## YAML configuration example\\1yaml\n",
        )
        .gsub(
          /^(\s*```)\n(?!>$|\n)/m,
          "\\1crystal\n",
        )
    end
  end

  DIR = Path[__DIR__, "..", "reference"].expand

  Builder.build(DIR)
end
