module Ameba
  enum Severity
    Error
    Warning
    Refactoring

    # Returns a symbol uniquely indicating severity.
    #
    # ```
    # Severity::Warning.symbol # => 'W'
    # ```
    def symbol
      to_s[0]
    end

    # Creates Severity by the name.
    #
    # ```
    # Severity.from_name('refactoring') # => Severity::Refactoring
    # Severity.from_name('foo-bar')     # => Exception: Incorrect severity name..
    # ```
    #
    def self.from_name(name : String)
      case name.downcase
      when "error"
        Error
      when "warning"
        Warning
      when "refactoring"
        Refactoring
      else
        raise "Incorrect severity name #{name}. Try one of #{Severity.values}"
      end
    end
  end

  # Converter for `YAML.mapping` which converts severity enum to and from YAML.
  class SeverityYamlConverter
    def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node)
      unless node.is_a?(YAML::Nodes::Scalar)
        raise "Severity must be a scalar, not #{node.class}"
      end

      case value = node.value
      when String then Severity.from_name(value)
      when Nil    then nil
      else
        raise "Incorrect severity: #{value}"
      end
    end

    def self.to_yaml(value : Severity, yaml : YAML::Nodes::Builder)
      yaml.scalar value
    end
  end
end
