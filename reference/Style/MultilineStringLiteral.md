# `Style/MultilineStringLiteral`

A rule that disallows multiline string literals not using
`<<-HEREDOC` markers.

For example, this is considered invalid:

```crystal
%(
  foo
  bar
)
```

And should be rewritten to the following:

```crystal
<<-HEREDOC
  foo
  bar
HEREDOC
```

## YAML configuration example

```yaml
Style/MultilineStringLiteral:
  Enabled: true
  AllowBackslashSplitStrings: true
```
