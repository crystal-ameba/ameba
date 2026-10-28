# `Style/RedundantNilInControlExpression`

A rule that disallows control expressions (`return`, `break` and `next`)
with `nil` argument.

This is considered invalid:

```crystal
def greeting(name)
  return nil unless name

  "Hello, #{name}"
end
```

And this is valid:

```crystal
def greeting(name)
  return unless name

  "Hello, #{name}"
end
```

## YAML configuration example

```yaml
Style/RedundantNilInControlExpression:
  Enabled: true
```
