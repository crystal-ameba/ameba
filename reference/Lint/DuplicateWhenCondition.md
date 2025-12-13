# `Lint/DuplicateWhenCondition`

Reports repeated conditions used in case `when` expressions.

This is considered invalid:

```crystal
case x
when .nil?
  do_something
when .nil?
  do_something_else
end
```

And this is valid:

```crystal
case x
when .nil?
  do_something
when Symbol
  do_something_else
end
```

## YAML configuration example

```yaml
Lint/DuplicateWhenCondition:
  Enabled: true
```
