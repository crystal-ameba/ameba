# `Typing/MacroCallArgumentTypeRestriction`

A rule that enforces call arguments to specific macros have a type restriction.
By default these macros are: `(class_)getter/setter/property(?/!)` and `record`.

For example, these are considered invalid:

```crystal
class Greeter
  getter name
  getter age = 0.days
  getter :height
end

record Task,
  cmd = "",
  args = %w[]
```

And these are considered valid:

```crystal
class Greeter
  getter name : String?
  getter age : Time::Span = 0.days
  getter height : Float64?
end

record Task,
  cmd : String = "",
  args : Array(String) = %w[]
```

The `DefaultValue` configuration option controls whether this rule applies to
call arguments that have a default value.

## YAML configuration example

```yaml
Typing/MacroCallArgumentTypeRestriction:
  Enabled: true
  DefaultValue: false
  MacroNames:
   - getter
   - getter?
   - getter!
   - class_getter
   - class_getter?
   - class_getter!
   - setter
   - setter?
   - setter!
   - class_setter
   - class_setter?
   - class_setter!
   - property
   - property?
   - property!
   - class_property
   - class_property?
   - class_property!
   - record
```
