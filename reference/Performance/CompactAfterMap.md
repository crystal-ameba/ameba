# `Performance/CompactAfterMap`

This rule is used to identify usage of `compact` calls that follow `map`.

For example, this is considered inefficient:

```crystal
%w[Alice Bob].map(&.match(/^A./)).compact
```

And can be written as this:

```crystal
%w[Alice Bob].compact_map(&.match(/^A./))
```

## YAML configuration example

```yaml
Performance/CompactAfterMap:
  Enabled: true
```
