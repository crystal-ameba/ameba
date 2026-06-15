require "file_utils"

module Ameba::Rule::Lint
  # A rule that enforces spec filenames to have `_spec` suffix.
  #
  # YAML configuration example:
  #
  # ```
  # Lint/SpecFilename:
  #   Enabled: true
  #   IgnoredPaths: [spec/support/** spec/fixtures/** spec/data/** spec/**/spec_helper.cr]
  # ```
  class SpecFilename < Base
    properties do
      since_version "1.6.0"
      description "Enforces spec filenames to have `_spec` suffix"
      ignored_paths %w[
        spec/support/**
        spec/fixtures/**
        spec/data/**
        spec/**/spec_helper.cr
      ]
    end

    MSG = "Spec filename should have `_spec` suffix: `%s.cr`, not `%s.cr`"

    private LOCATION = {1, 1}

    def test(source : Source)
      return if source.spec?

      path_ = Path[source.project_path].to_posix
      name = path_.stem
      path = path_.to_s

      return unless path.starts_with?("spec/")
      return unless path.ends_with?(".cr")

      ignored_paths.each do |pattern|
        return if File.match?(pattern, path)
      end

      expected = "#{name}_spec"

      issue_for(LOCATION, MSG % {expected, name}) do
        new_path =
          path_.sibling(expected + path_.extension)

        FileUtils.mv(path, new_path)
      end
    end
  end
end
