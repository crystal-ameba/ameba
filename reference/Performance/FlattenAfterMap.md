# `Performance/FlattenAfterMap`

This rule is used to identify usage of `flatten` calls that follow `map`.

For example, this is considered inefficient:

```crystal
%w[Alice Bob].map(&.chars).flatten
```

And can be written as this:

```crystal
%w[Alice Bob].flat_map(&.chars)
```

## YAML configuration example

```yaml
Performance/FlattenAfterMap:
  Enabled: true
```
