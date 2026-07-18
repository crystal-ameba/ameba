require "./base"

module Ameba::Rule::Security
  # A rule that disallows non-constant-time comparison of digests.
  #
  # Comparing a digest or HMAC signature with `==` returns as soon as
  # the first byte differs, so an attacker can recover the expected
  # value byte by byte from response timing. Use
  # `Crypto::Subtle.constant_time_compare` instead.
  #
  # For example, this is considered insecure:
  #
  # ```
  # signature == OpenSSL::HMAC.hexdigest(:sha256, key, data)
  # ```
  #
  # And should be written as:
  #
  # ```
  # Crypto::Subtle.constant_time_compare(signature, OpenSSL::HMAC.hexdigest(:sha256, key, data))
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Security/TimingAttack:
  #   Enabled: true
  #   DigestMethodNames:
  #     - digest
  #     - hexdigest
  #     - final
  #     - hexfinal
  # ```
  class TimingAttack < Base
    properties do
      since_version "1.7.0"
      description "Disallows non-constant-time comparison of digests"
      digest_method_names %w[digest hexdigest final hexfinal]
    end

    MSG = "Comparing digests with `%s` is vulnerable to timing attacks; use `Crypto::Subtle.constant_time_compare`"

    COMPARISON_OPERATORS = %w[== !=]

    def test(source, node : Crystal::Call)
      return unless node.name.in?(COMPARISON_OPERATORS)
      return unless node.args.size == 1
      return unless digest_call?(node.obj) || digest_call?(node.args.first)

      issue_for(node, MSG % node.name)
    end

    private def digest_call?(node)
      node.is_a?(Crystal::Call) &&
        node.name.in?(digest_method_names) &&
        !node.obj.nil?
    end
  end
end
