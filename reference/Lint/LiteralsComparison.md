# `Lint/LiteralsComparison`

This rule is used to identify comparisons between two literals.

They usually have the same result - except for non-primitive
types like containers, range or regex.

For example, this will be always false:

```crystal
"foo" == 42
```

## YAML configuration example

```yaml
Lint/LiteralsComparison:
  Enabled: true
```
