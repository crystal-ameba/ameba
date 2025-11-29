module Ameba
  # Helper module that is utilizes helpers for working with globs.
  module GlobUtils
    extend self

    # Returns all files that match specified globs.
    # Globs can have wildcards or be rejected:
    #
    # ```
    # find_files_by_globs(["**/*.cr", "!lib"])
    # ```
    def find_files_by_globs(globs, root = Dir.current)
      rejected = rejected_globs(globs, root)
      selected = globs - rejected

      expand(selected, root) - expand(rejected.map!(&.[1..-1]), root)
    end

    # Expands globs. Globs can point to files or even directories.
    #
    # ```
    # expand(["spec/*.cr", "src"]) # => all files in src folder + first level specs
    # ```
    def expand(globs, root = Dir.current)
      globs
        .flat_map do |glob|
          glob = Path[glob].expand(root).to_posix

          if File.directory?(glob)
            glob = glob / "**" / "*.{cr,ecr}"
          end

          Dir[glob.to_s]
        end
        .uniq!
        .select! { |path| File.file?(path) }
    end

    private def rejected_globs(globs, root = Dir.current)
      globs.select do |glob|
        glob.starts_with?('!') && !File.exists?(Path[glob].expand(root))
      end
    end
  end
end
