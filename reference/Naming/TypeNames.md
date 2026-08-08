# `Naming/TypeNames`

A rule that enforces type names in camelcase manner.

For example, these are considered valid:

```crystal
class ParseError < Exception
end

module HTTP
  class RequestHandler
  end
end

alias NumericValue = Float32 | Float64 | Int32 | Int64

lib LibYAML
end

struct TagDirective
end

enum Time::DayOfWeek
end
```

And these are invalid type names

```crystal
class My_class
end

module HTT_p
end

alias Numeric_value = Int32

lib Lib_YAML
end

struct Tag_directive
end

enum Time_enum::Day_of_week
end
```

## YAML configuration example

```yaml
Naming/TypeNames:
  Enabled: true
```
