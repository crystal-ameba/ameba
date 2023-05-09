require "colorize"

module Ameba
  enum Severity
    Error
    Warning
    Convention

    # Returns a symbol uniquely indicating severity.
    #
    # ```
    # Severity::Warning.symbol # => 'W'
    # ```
    def symbol : Char
      case self
      in Error      then 'E'
      in Warning    then 'W'
      in Convention then 'C'
      end
    end

    # Returns a color uniquely indicating severity.
    #
    # ```
    # Severity::Warning.color # => Colorize::ColorANSI::Red
    # ```
    def color : Colorize::Color
      case self
      in Error      then Colorize::ColorANSI::Red
      in Warning    then Colorize::ColorANSI::Red
      in Convention then Colorize::ColorANSI::Blue
      end
    end

    # Creates Severity by the name.
    #
    # ```
    # Severity.parse("convention") # => Severity::Convention
    # Severity.parse("foo-bar")    # => Exception: Incorrect severity name
    # ```
    def self.parse(name : String)
      super name
    rescue ArgumentError
      raise "Incorrect severity name #{name}. Try one of: #{values.map(&.to_s).join(", ")}"
    end
  end

  # Converter for `YAML.mapping` which converts severity enum to and from YAML.
  class SeverityYamlConverter
    def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node)
      unless node.is_a?(YAML::Nodes::Scalar)
        raise "Severity must be a scalar, not #{node.class}"
      end

      case value = node.value
      when String then Severity.parse(value)
      when Nil    then raise "Missing severity"
      else
        raise "Incorrect severity: #{value}"
      end
    end

    def self.to_yaml(value : Severity, yaml : YAML::Nodes::Builder)
      yaml.scalar value
    end
  end
end
