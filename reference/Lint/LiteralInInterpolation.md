# `Lint/LiteralInInterpolation`

A rule that disallows useless string interpolations
that contain a literal value instead of a variable or function.

For example:

```crystal
"Hello, #{:Ary}"
"There are #{4} cats"
```

## YAML configuration example

```yaml
Lint/LiteralInInterpolation:
  Enabled: true
```
