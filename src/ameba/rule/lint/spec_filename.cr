require "file_utils"

module Ameba::Rule::Lint
  # A rule that enforces spec filenames to have `_spec` suffix.
  #
  # YAML configuration example:
  #
  # ```
  # Lint/SpecFilename:
  #   Enabled: true
  #   IgnoredDirs: [spec/support spec/fixtures spec/data]
  #   IgnoredFilenames: [spec_helper]
  # ```
  class SpecFilename < Base
    properties do
      description "Enforces spec filenames to have `_spec` suffix"
      ignored_dirs %w[spec/support spec/fixtures spec/data]
      ignored_filenames %w[spec_helper]
    end

    MSG = "Spec filename should have `_spec` suffix: %s.cr, not %s.cr"

    private LOCATION = {1, 1}

    # TODO: fix the assumption that *source.path* contains relative path
    def test(source : Source)
      path_ = Path[source.path].to_posix
      name = path_.stem
      path = path_.to_s

      # check only files within spec/ directory
      return unless path.starts_with?("spec/")
      # check only files with `.cr` extension
      return unless path.ends_with?(".cr")
      # ignore files having `_spec` suffix
      return if name.ends_with?("_spec")

      # ignore known false-positives
      ignored_dirs.each do |substr|
        return if path.starts_with?("#{substr}/")
      end
      return if name.in?(ignored_filenames)

      expected = "#{name}_spec"

      issue_for LOCATION, MSG % {expected, name} do
        new_path =
          path_.sibling(expected + path_.extension)

        FileUtils.mv(path, new_path)
      end
    end
  end
end
