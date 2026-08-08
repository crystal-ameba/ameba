# `Style/ArrayLiteralSyntax`

Encourages the use of `Array(T).new` syntax for creating an array over `[] of T`.

Favour this:

```crystal
Array(Int32 | String?).new
```

Over this:

```crystal
[] of Int32 | String?
```

## YAML configuration example

```yaml
Style/ArrayLiteralSyntax:
  Enabled: true
```
