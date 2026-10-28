# `Style/IsANil`

A rule that disallows calls to `is_a?(Nil)` in favor of `nil?`.

This is considered bad:

```crystal
var.is_a?(Nil)
```

And needs to be written as:

```crystal
var.nil?
```

## YAML configuration example

```yaml
Style/IsANil:
  Enabled: true
```
