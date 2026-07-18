require "./base"

module Ameba::Rule::Security
  # A rule that disallows weak cryptographic hash algorithms.
  #
  # MD5 and SHA1 are broken for security purposes: collisions can be
  # produced at low cost, so they must not be used for signatures,
  # token generation or password hashing. If a weak algorithm is needed
  # for interoperability with a legacy system, disable this rule inline.
  #
  # For example, these are considered insecure:
  #
  # ```
  # Digest::MD5.hexdigest(payload)
  # OpenSSL::Digest.new("SHA1")
  # ```
  #
  # And should be written as:
  #
  # ```
  # Digest::SHA256.hexdigest(payload)
  # OpenSSL::Digest.new("SHA256")
  # ```
  #
  # Reference: [CWE-327](https://cwe.mitre.org/data/definitions/327.html)
  #
  # YAML configuration example:
  #
  # ```
  # Security/WeakCrypto:
  #   Enabled: true
  #   WeakAlgorithms:
  #     - MD5
  #     - SHA1
  # ```
  class WeakCrypto < Base
    properties do
      since_version "1.7.0"
      description "Disallows weak cryptographic hash algorithms"
      weak_algorithms %w[MD5 SHA1]
    end

    MSG = "Weak hash algorithm `%s` is not suitable for security purposes"

    DIGEST_PATH_NAME        = "Digest"
    OPENSSL_DIGEST_PATH     = %w[OpenSSL Digest]
    DIGEST_CONSTRUCTOR_NAME = "new"

    def test(source, node : Crystal::Path)
      names = node.names
      return unless names.size >= 2
      return unless names[-2] == DIGEST_PATH_NAME
      return unless (algorithm = names.last).in?(weak_algorithms)

      issue_for(node, MSG % algorithm)
    end

    def test(source, node : Crystal::Call)
      return unless node.name == DIGEST_CONSTRUCTOR_NAME
      return unless (obj = node.obj).is_a?(Crystal::Path)
      return unless obj.names.last(2) == OPENSSL_DIGEST_PATH
      return unless (arg = node.args.first?).is_a?(Crystal::StringLiteral)
      return unless (algorithm = arg.value.upcase).in?(weak_algorithms)

      issue_for(node, MSG % algorithm)
    end
  end
end
