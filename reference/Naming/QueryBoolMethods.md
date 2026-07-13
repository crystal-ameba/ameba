# `Naming/QueryBoolMethods`

A rule that disallows boolean properties without the `?` suffix - defined
using `Object#(class_)property` or `Object#(class_)getter` macros.

Favour this:

```crystal
class Person
  property? deceased = false
  getter? witty = true
end
```

Over this:

```crystal
class Person
  property deceased = false
  getter witty = true
end
```

## YAML configuration example

```yaml
Naming/QueryBoolMethods:
  Enabled: true
```
