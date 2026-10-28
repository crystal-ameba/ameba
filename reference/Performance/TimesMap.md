# `Performance/TimesMap`

This rule is used to identify usage of `times.map { ... }.to_a` calls.

For example, this is considered invalid:

```crystal
5.times.map { |i| i * 2 }.to_a
```

And it should be written as this:

```crystal
Array.new(5) { |i| i * 2 }
```

## YAML configuration example

```yaml
Performance/TimesMap:
  Enabled: true
```
