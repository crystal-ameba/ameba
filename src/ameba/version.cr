module Ameba
  VERSION = detect_version

  # Detects Ameba version from several sources.
  private macro detect_version
    {{ env("AMEBA_BUILD_VERSION") ||
         read_file?("#{__DIR__}/../../VERSION") ||
         `shards version "#{__DIR__}"`.chomp.stringify }}
  end

  class Version
    {% if flag?(:windows) %}
      private GIT_SHA = nil
    {% else %}
      private GIT_SHA =
        {{ `(git rev-parse --short HEAD || true) 2>/dev/null`.chomp.stringify }}.presence
    {% end %}

    # Cached version object.
    INSTANCE = begin
      version = SemanticVersion.parse(VERSION)
      unless version.build
        version = version.copy_with \
          build: GIT_SHA.try { |commit| "git.commit.#{commit}" }
      end
      new(version)
    end

    # Returns the current version as a `SemanticVersion` object.
    getter version : SemanticVersion

    def initialize(@version)
    end

    # Appends the version string to the given *io*.
    def to_s(io : IO) : Nil
      version.to_s(io)
    end

    # Returns the `version` without prerelease and build metadata.
    def for_production : String
      version.copy_with(prerelease: nil, build: nil).to_s
    end

    # Returns the `version` without prerelease and build metadata.
    def for_docs : String
      dev? ? "master" : for_production
    end

    # Returns `true` if the current `version` is a development version.
    def dev? : Bool
      version.prerelease.identifiers.any?("dev")
    end

    # # Returns `true` if the current `version` is a release candidate version.
    def release_candidate? : Bool
      version.prerelease.identifiers.any?(/^rc-?(\d+)?$/)
    end
  end
end
