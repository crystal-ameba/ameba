# `Style/PercentLiteralDelimiters`

A rule that enforces the consistent usage of `%`-literal delimiters.

Specifying `DefaultDelimiters` option will set all preferred delimiters at once. You
can continue to specify individual preferred delimiters via `PreferredDelimiters`
setting to override the default. In both cases the delimiters should be specified
as a string of two characters, or `nil` to ignore a particular `%`-literal / default.

Setting `IgnoreLiteralsContainingDelimiters` to `true` will ignore `%`-literals that
contain one or both delimiters.

## YAML configuration example

```yaml
Style/PercentLiteralDelimiters:
  Enabled: true
  DefaultDelimiters: '()'
  PreferredDelimiters:
    '%w': '[]'
    '%i': '[]'
    '%r': '{}'
  IgnoreLiteralsContainingDelimiters: false
```
