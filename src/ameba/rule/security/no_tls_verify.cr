require "./base"

module Ameba::Rule::Security
  # A rule that disallows disabling TLS certificate verification.
  #
  # Setting the verify mode to `NONE` accepts any certificate,
  # which exposes the connection to man-in-the-middle attacks.
  #
  # For example, this is considered insecure:
  #
  # ```
  # context.verify_mode = OpenSSL::SSL::VerifyMode::NONE
  # ```
  #
  # If a peer without a valid certificate must be reached in
  # a controlled environment, disable this rule inline.
  #
  # Reference: [CWE-295](https://cwe.mitre.org/data/definitions/295.html)
  #
  # YAML configuration example:
  #
  # ```
  # Security/NoTlsVerify:
  #   Enabled: true
  # ```
  class NoTlsVerify < Base
    properties do
      since_version "1.7.0"
      description "Disallows disabling TLS certificate verification"
    end

    MSG = "Disabling TLS certificate verification exposes the connection to man-in-the-middle attacks"

    VERIFY_NONE_PATH = %w[VerifyMode NONE]

    def test(source, node : Crystal::Path)
      return unless node.names.last(2) == VERIFY_NONE_PATH

      issue_for(node, MSG)
    end
  end
end
