# `Performance/AnyAfterFilter`

This rule is used to identify usage of `any?` calls that follow filters.

For example, this is considered invalid:

```crystal
[1, 2, 3].select { |e| e > 2 }.any?
[1, 2, 3].reject { |e| e >= 2 }.any?
```

And it should be written as this:

```crystal
[1, 2, 3].any? { |e| e > 2 }
[1, 2, 3].any? { |e| e < 2 }
```

## YAML configuration example

```yaml
Performance/AnyAfterFilter:
  Enabled: true
  FilterNames:
    - select
    - reject
```
