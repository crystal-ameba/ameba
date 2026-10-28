# `Lint/EmptyEnsure`

A rule that disallows empty `ensure` statement.

For example, this is considered invalid:

```crystal
def some_method
  do_some_stuff
ensure
end

begin
  do_some_stuff
ensure
end
```

And it should be written as this:

```crystal
def some_method
  do_some_stuff
ensure
  do_something_else
end

begin
  do_some_stuff
ensure
  do_something_else
end
```

## YAML configuration example

```yaml
Lint/EmptyEnsure:
  Enabled: true
```
