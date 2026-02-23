module Ameba::Rule::Lint
  # A rule that detects calls to deprecated methods.
  #
  # This helps identify usage of methods that are marked as deprecated
  # in the Crystal standard library or dependencies.
  #
  # YAML configuration example:
  #
  # ```
  # Lint/DeprecatedMethods:
  #   Enabled: true
  # ```
  class DeprecatedMethods < Base
    properties do
      since_version "1.7.0"
      description "Detects calls to deprecated methods"
    end

    MSG = "Call to deprecated method `%s` detected"

    # List of known deprecated methods in Crystal stdlib
    # This can be expanded as more methods are deprecated
    DEPRECATED_METHODS = {
      # File/IO deprecations
      "File.readable?" => "Use File::Info#readable? instead",
      "File.writable?" => "Use File::Info#writable? instead",
      "File.executable?" => "Use File::Info#executable? instead",
      
      # Time deprecations  
      "Time.now" => "Use Time.local or Time.utc instead",
      "Time.new" => "Use Time.local or Time.utc instead",
      
      # String deprecations
      "String#size" => "Use String#bytesize for byte size or String#chars for character count",
    }

    # Simple replacements that can be autocorrected
    # Maps deprecated method => replacement
    AUTOCORRECT = {
      "Time.now" => "Time.local",
      "Time.new" => "Time.local",
    }

    def test(source, node : Crystal::Call)
      method_name = node.name
      obj = node.obj
      
      # Build full method name if there's a receiver
      full_name = if obj.is_a?(Crystal::Path)
        "#{obj.names.join("::")}.#{method_name}"
      elsif obj.is_a?(Crystal::Call)
        # Chain of calls - skip for now
        return
      else
        method_name
      end

      # Check if this method is in our deprecated list
      if message = DEPRECATED_METHODS[full_name]?
        # Check if we can autocorrect this
        if replacement = AUTOCORRECT[full_name]?
          issue_for node, "#{MSG % full_name}: #{message}" do |corrector|
            corrector.replace(node, replacement)
          end
        else
          issue_for node, "#{MSG % full_name}: #{message}"
        end
      end
    end
  end
end
