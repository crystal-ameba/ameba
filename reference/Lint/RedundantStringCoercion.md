# `Lint/RedundantStringCoercion`

A rule that disallows string conversion in string interpolation,
which is redundant.

For example, this is considered invalid:

```crystal
"Hello, #{name.to_s}"
```

And this is valid:

```crystal
"Hello, #{name}"
```

## YAML configuration example

```yaml
Lint/RedundantStringCoercion:
  Enabled: true
```
