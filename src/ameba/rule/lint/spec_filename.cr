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
      description "Enforces spec filenames to have a `_spec` suffix"
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

      project_path = Path[source.project_path]
        .to_posix
        .to_s

      return unless project_path.starts_with?("spec/")
      return unless project_path.ends_with?(".cr")

      ignored_paths.each do |pattern|
        return if File.match?(pattern, project_path)
      end

      path = Path[source.path]
      name = path.stem

      expected = "#{name}_spec"

      issue_for(LOCATION, MSG % {expected, name}) do
        new_path =
          path.sibling(expected + path.extension)

        FileUtils.mv(path, new_path)
      end
    end
  end
end
