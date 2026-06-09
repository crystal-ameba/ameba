# `Lint/BadDirective`

A rule that reports incorrect comment directives for Ameba.

For example, the user can mistakenly add a directive
to disable a rule that even doesn't exist:

```crystal
# ameba:disable BadRuleName
def foo
  :bar
end
```

## YAML configuration example

```yaml
Lint/BadDirective:
  Enabled: true
```
