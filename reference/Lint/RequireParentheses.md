# `Lint/RequireParentheses`

A rule that disallows method calls with at least one argument, where no
parentheses are used around the argument list, and a logical operator
(`&&` or `||`) is used within the argument list.

For example, this is considered invalid:

```crystal
if foo.includes? "bar" || foo.includes? "baz"
  # ...
end
```

And need to be written as:

```crystal
if foo.includes?("bar") || foo.includes?("baz")
  # ...
end
```

## YAML configuration example

```yaml
Lint/RequireParentheses:
  Enabled: true
```
