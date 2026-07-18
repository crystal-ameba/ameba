require "./base"

module Ameba::Rule::Security
  # A rule that disallows the default pseudo-random generator for
  # security-sensitive values.
  #
  # `Random` is a fast pseudo-random generator whose output can be
  # predicted, which makes tokens, session ids and other secrets
  # generated with it guessable. `Random::Secure` uses the system
  # CSPRNG and should be used instead.
  #
  # For example, this is considered insecure:
  #
  # ```
  # token = Random.new.hex(32)
  # ```
  #
  # And should be written as:
  #
  # ```
  # token = Random::Secure.hex(32)
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Security/InsecureRandom:
  #   Enabled: true
  #   TokenMethodNames:
  #     - hex
  #     - base64
  #     - urlsafe_base64
  #     - random_bytes
  # ```
  class InsecureRandom < Base
    properties do
      since_version "1.7.0"
      description "Disallows `Random` for security-sensitive values"
      token_method_names %w[hex base64 urlsafe_base64 random_bytes]
    end

    MSG = "Use `Random::Secure` to generate security-sensitive values"

    RANDOM_PATH             = %w[Random]
    RANDOM_CONSTRUCTOR_NAME = "new"

    def test(source, node : Crystal::Call)
      return unless node.name.in?(token_method_names)
      return unless insecure_random?(node.obj)

      issue_for(node, MSG)
    end

    private def insecure_random?(obj)
      case obj
      when Crystal::Path
        obj.names == RANDOM_PATH
      when Crystal::Call
        obj.name == RANDOM_CONSTRUCTOR_NAME &&
          (path = obj.obj).is_a?(Crystal::Path) &&
          path.names == RANDOM_PATH
      else
        false
      end
    end
  end
end
