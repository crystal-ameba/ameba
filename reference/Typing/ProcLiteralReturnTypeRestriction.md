# `Typing/ProcLiteralReturnTypeRestriction`

A rule that enforces that `Proc` literals have a return type.

For example, these are considered invalid:

```crystal
greeter = ->(name : String) { "Hello #{name}" }
```

```crystal
task = -> { Task.new("execute this command") }
```

And these are valid:

```crystal
greeter = ->(name : String) : String { "Hello #{name}" }
```

```crystal
task = -> : Task { Task.new("execute this command") }
```

## YAML configuration example

```yaml
Typing/ProcLiteralReturnTypeRestriction:
  Enabled: true
```
