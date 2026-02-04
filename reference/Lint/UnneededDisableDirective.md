# `Lint/UnneededDisableDirective`

A rule that reports unneeded disable directives.
For example, this is considered invalid:

```crystal
# ameba:disable Style/PredicateName
def comment?
  do_something
end
```

As the predicate name is correct and the comment directive does not
have any effect, the snippet should be written as the following:

```crystal
def comment?
  do_something
end
```

## YAML configuration example

```yaml
Lint/UnneededDisableDirective:
  Enabled: true
```
