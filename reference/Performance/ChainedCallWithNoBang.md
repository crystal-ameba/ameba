# `Performance/ChainedCallWithNoBang`

This rule is used to identify usage of chained calls not utilizing
the bang method variants.

For example, this is considered inefficient:

```crystal
names = %w[Alice Bob]
chars = names
  .flat_map(&.chars)
  .uniq
  .sort
```

And can be written as this:

```crystal
names = %w[Alice Bob]
chars = names
  .flat_map(&.chars)
  .uniq!
  .sort!
```

## YAML configuration example

```yaml
Performance/ChainedCallWithNoBang:
  Enabled: true
  CallNames:
    - uniq
    - unstable_sort
    - sort
    - sort_by
    - shuffle
    - reverse
```
