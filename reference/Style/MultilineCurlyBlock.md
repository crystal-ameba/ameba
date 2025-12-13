# `Style/MultilineCurlyBlock`

A rule that disallows multi-line blocks that use curly brackets
instead of `do`...`end`.

For example, this is considered invalid:

```crystal
(0..10).map { |i|
  i * 2
}
```

And should be rewritten to the following:

```crystal
(0..10).map do |i|
  i * 2
end
```

## YAML configuration example

```yaml
Style/MultilineCurlyBlock:
  Enabled: true
```
