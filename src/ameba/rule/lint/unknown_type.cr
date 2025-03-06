module Ameba::Rule::Lint
  # A rule that uses semantic information to check parameter and type declaration restrictions
  # to ensure that those types exist within the current semantic context, even if the
  # code isn't used during compilation.
  #
  # By default, the Crystal compiler does not do any semantic analysis to code that isn't used.
  # That can lead to issues like this, where a typo can cause unexpected behavior:
  #
  # ```
  # class MessageHandler
  #   def on_request(msg)
  #     # generic message handling
  #   end

  #   def on_request(msg : SpecificMessageType)
  #     # specific message handling
  #   end
  # end
  # ```
  #
  # If `SpecificMessageType` is misspelled, this code will compile and execute normally, but
  # the method overloading won't happen for the specific message type.
  #
  # This is considered invalid:
  #
  # ```
  # count : Int3 = 1
  #
  # def hello(name : Str)
  #   puts "Hello, #{name}!"
  # end
  # ```
  #
  # And this is considered valid:
  #
  # ```
  # count : Int32 = 1
  #
  # def hello(name : String)
  #   puts "Hello, #{name}!"
  # end
  # ```
  #
  # YAML configuration example:
  #
  # ```
  # Lint/UnknownType:
  #   Enabled: true
  # ```
  class UnknownType < Base
    properties do
      since_version "1.7.0"
      description "Reports unknown types"
      severity :error
    end

    MSG = "Unknown type"

    def test(source, context : SemanticContext?)
      return if context.nil?

      AST::SemanticVisitor.new self, source, context
    end

    def test(source, node : Crystal::TypeDeclaration, current_type : Crystal::Type)
      return if current_type.lookup_type?(node.declared_type)

      validate_type(source, node.declared_type, current_type)
    end

    def test(source, node : Crystal::Arg, current_type : Crystal::Type)
      return if (restriction = node.restriction).nil?

      validate_type(source, restriction, current_type)
    end

    private def validate_type(source, node : Crystal::ASTNode, current_type : Crystal::Type) : Nil
      case node
      when Crystal::Path
        return if current_type.lookup_type?(node)

        issue_for node, MSG
      when Crystal::Union
        node.types.each do |type|
          validate_type(source, type, current_type)
        end
      when Crystal::ProcNotation
        node.inputs.try &.each { |i| validate_type(source, i, current_type) }
        node.output.try { |i| validate_type(source, i, current_type) }
      when Crystal::TypeOf
        node.expressions.each do |type|
          validate_type(source, type, current_type)
        end
      when Crystal::Generic
        validate_type(source, node.name, current_type)

        node.type_vars.each do |type|
          validate_type(source, type, current_type)
        end

        node.named_args.try &.each do |arg|
          validate_type(source, arg.value, current_type)
        end
      when Crystal::Underscore, Crystal::Self
        # Okay
      end
    end
  end
end
