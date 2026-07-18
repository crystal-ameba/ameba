require "./base"

module Ameba::Rule::Security
  # A rule that disallows hardcoded secret values.
  #
  # Credentials committed to the repository are visible to anyone
  # with read access to the code and its full history. Load them
  # from the environment or a credentials store instead.
  #
  # Two kinds of secrets are detected:
  #
  # 1. String literals matching well-known credential formats
  #    (AWS access keys, GitHub/Slack/Stripe tokens, private keys),
  #    regardless of where they appear.
  # 2. String literals assigned to secret-named targets: local,
  #    instance and class variables, constants, named arguments,
  #    hash keys, and method parameter defaults.
  #
  # For example, these are considered insecure:
  #
  # ```
  # password = "s3cr3t_p4ssw0rd"
  # login(password: "s3cr3t_p4ssw0rd")
  # key = "AKIAIOSFODNN7EXAMPLE1"
  # ```
  #
  # And should be written as:
  #
  # ```
  # password = ENV["DB_PASSWORD"]
  # ```
  #
  # The name pattern matches whole words only (`api_key` matches,
  # `compass` does not), and values shorter than `MinLength` or
  # looking like placeholders are ignored.
  #
  # Reference: [CWE-798](https://cwe.mitre.org/data/definitions/798.html)
  #
  # YAML configuration example:
  #
  # ```
  # Security/HardcodedSecret:
  #   Enabled: true
  #   SecretNamePattern: password|passwd|secret|api_key|apikey|access_key|private_key|auth_token|credentials?
  #   MinLength: 8
  # ```
  class HardcodedSecret < Base
    properties do
      since_version "1.7.0"
      description "Disallows hardcoded secret values"
      secret_name_pattern "password|passwd|secret|api_key|apikey|access_key|private_key|auth_token|credentials?"
      min_length 8
    end

    MSG       = "Hardcoded secret detected; load it from the environment or a credentials store"
    MSG_TOKEN = "Hardcoded %s detected; load it from the environment or a credentials store"

    PLACEHOLDER_PATTERN = /example|sample|changeme|placeholder|dummy|x{4,}|\*{3,}|<[^>]+>/i

    TOKEN_PATTERNS = {
      /\bAKIA[0-9A-Z]{16}\b/                     => "AWS access key",
      /\b(?:ghp|gho|ghu|ghs)_[A-Za-z0-9]{36,}\b/ => "GitHub token",
      /\bgithub_pat_[A-Za-z0-9_]{22,}\b/         => "GitHub token",
      /\bsk_live_[A-Za-z0-9]{20,}\b/             => "Stripe live key",
      /\bAIza[0-9A-Za-z\-_]{35}\b/               => "Google API key",
      /\bxox[pborsa]-[A-Za-z0-9-]{10,}\b/        => "Slack token",
      /-----BEGIN (?:[A-Z]+ )?PRIVATE KEY-----/  => "private key",
    }

    def test(source, node : Crystal::StringLiteral)
      return unless label = token_label(node.value)

      issue_for(node, MSG_TOKEN % label)
    end

    def test(source, node : Crystal::Assign)
      check(source, node, target_name(node.target), node.value)
    end

    def test(source, node : Crystal::Call)
      node.named_args.try &.each do |arg|
        check(source, arg, arg.name, arg.value)
      end
    end

    def test(source, node : Crystal::HashLiteral)
      node.entries.each do |entry|
        check(source, entry.value, key_name(entry.key), entry.value)
      end
    end

    def test(source, node : Crystal::Def)
      node.args.each do |arg|
        next unless value = arg.default_value

        check(source, value, arg.name, value)
      end
    end

    private def check(source, node, name, value)
      return unless name && secret_name?(name)
      return unless value.is_a?(Crystal::StringLiteral)
      return if token_label(value.value)
      return unless suspicious?(value.value)

      issue_for(node, MSG)
    end

    private def token_label(value)
      TOKEN_PATTERNS.each do |pattern, label|
        return label if value.matches?(pattern)
      end
    end

    private def target_name(target)
      case target
      when Crystal::Var, Crystal::InstanceVar, Crystal::ClassVar
        target.name
      when Crystal::Path
        target.names.last
      end
    end

    private def key_name(key)
      case key
      when Crystal::StringLiteral then key.value
      when Crystal::SymbolLiteral then key.value
      end
    end

    private def secret_name?(name)
      name.matches?(/(?:^|[^a-z0-9])(?:#{secret_name_pattern})(?:[^a-z0-9]|$)/i)
    end

    private def suspicious?(value)
      value.size >= min_length && !value.matches?(PLACEHOLDER_PATTERN)
    end
  end
end
