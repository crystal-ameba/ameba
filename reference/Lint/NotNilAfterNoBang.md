# `Lint/NotNilAfterNoBang`

This rule is used to identify usage of `index/rindex/find/match` calls
followed by a call to `not_nil!`.

For example, this is considered a code smell:

```crystal
%w[Alice Bob].find(&.chars.any?(&.in?('o', 'b'))).not_nil!
```

And can be written as this:

```crystal
%w[Alice Bob].find!(&.chars.any?(&.in?('o', 'b')))
```

## YAML configuration example

```yaml
Lint/NotNilAfterNoBang:
  Enabled: true
```
