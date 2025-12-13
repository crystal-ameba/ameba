# `Lint/RandZero`

A rule that disallows `rand(0)` and `rand(1)` calls.
Such calls always return `0`.

For example:

```crystal
rand(1)
```

Should be written as:

```crystal
rand
# or
rand(2)
```

## YAML configuration example

```yaml
Lint/RandZero:
  Enabled: true
```
