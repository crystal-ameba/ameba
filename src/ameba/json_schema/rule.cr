module Ameba::JSONSchema
  # :nodoc:
  #
  # Writes the JSON schema matching all of the types given by *paths*
  # within the *rule* type.
  #
  # Each path starts with the name of an instance variable (or a type, given
  # as a string, in which case *rule* can be `nil`), followed by
  # the steps leading to a type nested within its own, each one being
  # a tuple of the union member index, and the type variable index or
  # named tuple key (`nil` standing for the flags enum member names).
  # Nested types are never referred to by their names, which allows them
  # to be private, or defined after the rule class itself.
  #
  # Schemas of the nested `items`, `prefixItems`, `properties` and
  # `additionalProperties` are written by expanding this macro again,
  # one level at a time.
  #
  # Types not supported by the JSON schema leave it unconstrained.
  #
  # With *default* given, it is written as well, and so are the defaults
  # of each one of its keys (for hashes and named tuples).
  #
  # NOTE: It needs to be called from within a method body, so that the
  # instance variables of the *rule* are known.
  macro write_type(builder, rule, *paths, default = nil)
    {%
      instance_vars = rule ? rule.resolve.instance_vars : [] of MetaVar
      types = [] of TypeNode
      type_paths = [] of ArrayLiteral

      paths.each do |path|
        type =
          if path.first.is_a?(StringLiteral)
            parse_type(path.first).resolve
          else
            instance_vars.find(&.name.== path.first.id).type
          end

        path[1..-1].each do |step|
          member = type.union? ? type.union_types[step[0]] : type

          if step[1].is_a?(NilLiteral)
            type = ::String
          elsif step[1].is_a?(StringLiteral)
            type = member[step[1].id]
          else
            type = member.type_vars[step[1]]
          end
        end

        unless types.includes?(type)
          types << type
          type_paths << path
        end
      end

      json_types = [] of StringLiteral
      refs = [] of StringLiteral
      items = [] of ArrayLiteral
      tuples = [] of ArrayLiteral
      named_tuples = [] of TypeNode
      properties = {} of StringLiteral => ArrayLiteral
      additional_properties = [] of ArrayLiteral
      unconstrained = false

      types.each_with_index do |type, type_index|
        path = type_paths[type_index]

        (type.union? ? type.union_types : [type]).each_with_index do |member, index|
          if member == ::Nil
            json_types << "null"
          elsif member == ::Bool
            json_types << "boolean"
          elsif member <= ::Int
            json_types << "integer"
          elsif member <= ::Float
            json_types << "number"
          elsif member == ::Ameba::Severity
            # Described within `$defs` (unless mixed with other types)
            refs << "#/$defs/Severity"
          elsif member < ::Enum && member.annotation(::Flags)
            # Flags enums are parsed from a sequence
            json_types << "array"
            items << path + [{index, nil}]
          elsif member == ::String || member == ::Path || member == ::Time || member < ::Enum
            json_types << "string"
          elsif member <= ::Array || member <= ::Set
            json_types << "array"
            items << path + [{index, 0}]
          elsif member <= ::Tuple
            json_types << "array"
            tuples << member.type_vars.map_with_index { |_, i| path + [{index, i}] }
          elsif member <= ::Hash
            json_types << "object"
            additional_properties << path + [{index, 1}]
          elsif member <= ::NamedTuple
            json_types << "object"
            named_tuples << member

            member.keys.each do |key|
              properties[key.stringify] =
                (properties[key.stringify] || [] of ArrayLiteral) + [path + [{index, key.stringify}]]
            end
          else
            unconstrained = true
          end
        end
      end

      # Tuples are described by position, unless mixed with other sequences
      positional = tuples.size == 1 && items.empty?
      unless positional
        tuples.each do |tuple|
          items = items + tuple
        end
      end
    %}

    {% unless unconstrained %}
      {% if json_types.empty? && !refs.empty? %}
        {{ builder }}.field("$ref", {{ refs.first }})
      {% elsif !refs.empty? %}
        {% json_types << "string" %}
      {% end %}

      # Duplicates (and integers within numbers) are skipped,
      # with `"null"` (if present) placed last
      {% nilable = json_types.includes?("null") %}

      {% json_types = json_types.reject(&.== "integer") if json_types.includes?("number") %}
      {% json_types = json_types.reject(&.== "null").uniq %}
      {% json_types << "null" if nilable %}

      {% if json_types.size == 1 %}
        {{ builder }}.field("type", {{ json_types.first }})
      {% elsif !json_types.empty? %}
        {{ builder }}.string("type")
        {{ builder }}.array do
          {% for json_type in json_types %}
            {{ builder }}.string({{ json_type }})
          {% end %}
        end
      {% end %}

      {% unless items.empty? %}
        {{ builder }}.string("items")
        {{ builder }}.object do
          ::Ameba::JSONSchema.write_type({{ builder }}, {{ rule }}, {{ items.splat }})
        end
      {% end %}

      {% if positional %}
        {% tuple = tuples.first %}

        {% unless tuple.empty? %}
          {{ builder }}.string("prefixItems")
          {{ builder }}.array do
            {% for tuple_path in tuple %}
              {{ builder }}.object do
                ::Ameba::JSONSchema.write_type({{ builder }}, {{ rule }}, {{ tuple_path }})
              end
            {% end %}
          end
        {% end %}

        # Tuples are parsed from sequences of their exact size
        {{ builder }}.field("minItems", {{ tuple.size }})
        {{ builder }}.field("maxItems", {{ tuple.size }})
      {% end %}

      {% hash_defaults = default && !additional_properties.empty? %}
      {% named_tuple_defaults = default && named_tuples.size == 1 %}

      {% if !properties.empty? || hash_defaults %}
        {{ builder }}.string("properties")
        {{ builder }}.object do
          {% for key, key_paths in properties %}
            {{ builder }}.string({{ key }})
            {{ builder }}.object do
              ::Ameba::JSONSchema.write_type({{ builder }}, {{ rule }}, {{ key_paths.splat }})

              {% if named_tuple_defaults %}
                if (%named_tuple = {{ default }}).is_a?(NamedTuple)
                  {{ builder }}.string("default")
                  ::Ameba::JSONSchema.write_value({{ builder }}, %named_tuple[{{ key.id.symbolize }}])
                end
              {% end %}
            end
          {% end %}

          {% if hash_defaults %}
            if (%hash = {{ default }}).is_a?(Hash)
              %hash.each do |%key, %value|
                {% unless properties.empty? %}
                  # Keys of named tuples (within the same union) are already written
                  next if {{ properties.keys }}.includes?(%key.to_s)
                {% end %}

                {{ builder }}.string(%key.to_s)
                {{ builder }}.object do
                  ::Ameba::JSONSchema.write_type({{ builder }}, {{ rule }}, {{ additional_properties.splat }})

                  {{ builder }}.string("default")
                  ::Ameba::JSONSchema.write_value({{ builder }}, %value)
                end
              end
            end
          {% end %}
        end
      {% end %}

      # Named tuples are parsed only when all of their non-nilable keys are present
      {% if named_tuples.size == 1 && additional_properties.empty? %}
        {% required = named_tuples.first.keys.reject { |key| named_tuples.first[key].nilable? } %}

        {% unless required.empty? %}
          {{ builder }}.string("required")
          {{ builder }}.array do
            {% for key in required %}
              {{ builder }}.string({{ key.stringify }})
            {% end %}
          end
        {% end %}
      {% end %}

      {% unless additional_properties.empty? %}
        {{ builder }}.string("additionalProperties")
        {{ builder }}.object do
          ::Ameba::JSONSchema.write_type({{ builder }}, {{ rule }}, {{ additional_properties.splat }})
        end
      {% end %}
    {% end %}

    {% if default %}
      {{ builder }}.string("default")
      ::Ameba::JSONSchema.write_value({{ builder }}, {{ default }})
    {% end %}
  end

  # :nodoc:
  #
  # Writes the given *value* as JSON, with the keys of all of the hashes
  # within written as strings, the same way as within `properties`
  # (since not all of them can be serialized as JSON object keys).
  def self.write_value(builder : JSON::Builder, value : Hash | NamedTuple) : Nil
    builder.object do
      value.each do |key, item|
        builder.string(key.to_s)
        write_value(builder, item)
      end
    end
  end

  # :ditto:
  def self.write_value(builder : JSON::Builder, value : Array | Set | Tuple) : Nil
    builder.array do
      value.each do |item|
        write_value(builder, item)
      end
    end
  end

  # :ditto:
  def self.write_value(builder : JSON::Builder, value : Severity) : Nil
    # The same way as within `$defs`
    builder.string(value.to_s)
  end

  # :ditto:
  def self.write_value(builder : JSON::Builder, value) : Nil
    value.to_json(builder)
  end
end

abstract class Ameba::Rule::Base
  # :nodoc:
  #
  # Writes the JSON schema of the rule, with its properties described by
  # the types of their instance variables.
  #
  # NOTE: Abstract rules can't be loaded, and so they can't be described.
  def self.to_json_schema(builder : JSON::Builder) : Nil
    {% if @type.abstract? %}
      raise "Abstract rule `#{name}` can't be described"
    {% else %}
      # Default values are read from the rule loaded with no configuration
      # given, since the ones written within `properties` can be autocasted
      # (like symbols into enum members)
      rule = new

      {%
        properties = @type.instance_vars.select(&.annotation(::Ameba::Config::RuleConfig::Property))

        # Implicitly defined ones go last
        properties =
          properties.reject(&.annotation(::Ameba::Config::RuleConfig::Property)[:built_in]) +
            properties.select(&.annotation(::Ameba::Config::RuleConfig::Property)[:built_in])
      %}

      builder.string(rule_name)
      builder.object do
        builder.field("$ref", "#/$defs/BaseRule")
        builder.field("$comment", documentation_url)
        builder.field("title", rule_name)

        if description = rule.description
          builder.field("description", description)
        end

        builder.string("properties")
        builder.object do
          {% for ivar in properties %}
            {% property = ivar.annotation(::Ameba::Config::RuleConfig::Property) %}

            # Described within the rule itself
            {% unless ivar.name == "description" %}
              # Properties common to all of the rules are described within
              # `BaseRule`, unless their defaults differ for this rule
              if {{ property[:base] ? "rule.@#{ivar.name} != #{property[:base_default]}".id : true }}
                builder.string({{ property[:key] }})
                builder.object do
                  ::Ameba::JSONSchema.write_type(builder, {{ @type }}, [{{ ivar.name.symbolize }}], default: rule.@{{ ivar.name }})
                end
              end
            {% end %}
          {% end %}
        end
      end
    {% end %}
  end
end
