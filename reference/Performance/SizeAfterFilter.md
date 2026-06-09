# `Performance/SizeAfterFilter`

This rule is used to identify usage of `size` calls that follow filter.

For example, this is considered invalid:

```crystal
[1, 2, 3].select { |e| e > 2 }.size
[1, 2, 3].reject { |e| e < 2 }.size
[1, 2, 3].select(&.< 2).size
[0, 1, 2].select(&.zero?).size
[0, 1, 2].reject(&.zero?).size
```

And it should be written as this:

```crystal
[1, 2, 3].count { |e| e > 2 }
[1, 2, 3].count { |e| e >= 2 }
[1, 2, 3].count(&.< 2)
[0, 1, 2].count(&.zero?)
[0, 1, 2].count(&.!= 0)
```

## YAML configuration example

```yaml
Performance/SizeAfterFilter:
  Enabled: true
  FilterNames:
    - select
    - reject
```
