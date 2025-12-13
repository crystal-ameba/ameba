# `Style/Elsif`

A rule that encourages the use of `case/when` syntax over `if/elsif`.

For example, this is considered invalid:

```crystal
if foo
  do_something_foo
elsif bar
  do_something_bar
end
```

And should be replaced by the following:

```crystal
case
when foo
  do_something_foo
when bar
  do_something_bar
end
```

## YAML configuration example

```yaml
Style/Elsif:
  Enabled: true
  MaxBranches: 0
```
