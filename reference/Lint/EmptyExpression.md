# `Lint/EmptyExpression`

A rule that disallows empty expressions.

This is considered invalid:

```crystal
foo = ()

if ()
  bar
end
```

And this is valid:

```crystal
foo = (some_expression)

if (some_expression)
  bar
end
```

## YAML configuration example

```yaml
Lint/EmptyExpression:
  Enabled: true
```
