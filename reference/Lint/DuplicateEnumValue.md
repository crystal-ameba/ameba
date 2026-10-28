# `Lint/DuplicateEnumValue`

A rule that reports duplicated `enum` member values.

```crystal
enum Foo
  Foo = 1
  Bar = 2
  Baz = 2 # duplicate value
end
```

## YAML configuration example

```yaml
Lint/DuplicateEnumValue:
  Enabled: true
```
