# `Style/WhileTrue`

A rule that disallows the use of `while true` instead of using the idiomatic `loop`

For example, this is considered invalid:

```crystal
while true
  do_something
  break if some_condition
end
```

And should be replaced by the following:

```crystal
loop do
  do_something
  break if some_condition
end
```

## YAML configuration example

```yaml
Style/WhileTrue:
  Enabled: true
```
