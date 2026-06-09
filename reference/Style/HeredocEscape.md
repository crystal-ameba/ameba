# `Style/HeredocEscape`

A rule that enforces heredoc variant that escapes interpolation or control
chars in a heredoc body. The opposite is enforced too - i.e. regular heredoc
variant that doesn't escape interpolation or control chars in a heredoc body,
when there is no need to escape it.

For example, this is considered invalid:

```crystal
<<-DOC
  This is an escaped \#{:interpolated} string \\n
  DOC
```

And should be written as:

```crystal
<<-'DOC'
  This is an escaped #{:interpolated} string \n
  DOC
```

## YAML configuration example

```yaml
Style/HeredocEscape:
  Enabled: true
```
