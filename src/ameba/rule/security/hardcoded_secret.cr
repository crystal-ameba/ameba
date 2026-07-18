require "./base"

module Ameba::Rule::Security
  # A rule that disallows hardcoded secret values.
  #
  # Credentials committed to the repository are visible to anyone
  # with read access to the code and its full history. Load them
  # from the environment or a credentials store instead.
  #
  # For example, this is considered insecure:
  #
  # ```
  # password = "s3cr3t_p4ssw0rd"
  # ```
  #
  # And should be written as:
  #
  # ```
  # password = ENV["DB_PASSWORD"]
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Security/HardcodedSecret:
  #   Enabled: true
  #   SecretNamePattern: (password|passwd|secret|api_key|apikey|access_key|private_key|auth_token|credentials?)
  #   MinLength: 8
  # ```
  class HardcodedSecret < Base
    properties do
      since_version "1.7.0"
      description "Disallows hardcoded secret values"
      secret_name_pattern "(password|passwd|secret|api_key|apikey|access_key|private_key|auth_token|credentials?)"
      min_length 8
    end

    MSG = "Hardcoded secret detected; load it from the environment or a credentials store"

    PLACEHOLDER_PATTERN = /example|sample|changeme|placeholder|dummy|x{4,}|\*{3,}|<[^>]+>/i

    def test(source, node : Crystal::Assign)
      return unless name = target_name(node.target)
      return unless name.matches?(/#{secret_name_pattern}/i)
      return unless (value = node.value).is_a?(Crystal::StringLiteral)
      return unless suspicious?(value.value)

      issue_for(node, MSG)
    end

    private def target_name(target)
      case target
      when Crystal::Var, Crystal::InstanceVar, Crystal::ClassVar
        target.name
      when Crystal::Path
        target.names.last
      end
    end

    private def suspicious?(value)
      value.size >= min_length && !value.matches?(PLACEHOLDER_PATTERN)
    end
  end
end
