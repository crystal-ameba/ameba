# `Lint/WhitespaceAroundMacroExpression`

A rule that checks for whitespace around macro expressions.

This is considered invalid:

```crystal
{{foo}}
```

And it has to written as this instead:

```crystal
{{ foo }}
```

## YAML configuration example

```yaml
Lint/WhitespaceAroundMacroExpression:
  Enabled: true
```
