# `Performance/ExcessiveAllocations`

This rule is used to identify excessive collection allocations,
that can be avoided by using `each_<member>` instead of `<collection>.each`.

For example, this is considered inefficient:

```crystal
"Alice".chars.each { |c| puts c }
"Alice\nBob".lines.each { |l| puts l }
```

And can be written as this:

```crystal
"Alice".each_char { |c| puts c }
"Alice\nBob".each_line { |l| puts l }
```

## YAML configuration example

```yaml
Performance/ExcessiveAllocations:
  Enabled: true
  CallNames:
    codepoints: each_codepoint
    graphemes: each_grapheme
    chars: each_char
    lines: each_line
```
