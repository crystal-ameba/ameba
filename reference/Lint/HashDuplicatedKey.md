# `Lint/HashDuplicatedKey`

A rule that disallows duplicated keys in hash literals.

This is considered invalid:

```crystal
h = {"foo" => 1, "bar" => 2, "foo" => 3}
```

And it has to written as this instead:

```crystal
h = {"foo" => 1, "bar" => 2}
```

## YAML configuration example

```yaml
Lint/HashDuplicatedKey:
  Enabled: true
```
