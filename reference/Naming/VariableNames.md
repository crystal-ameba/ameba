# `Naming/VariableNames`

A rule that enforces variable names to be in underscored case.

For example, these variable names are considered valid:

```crystal
var_name = 1
name = 2
_another_good_name = 3
```

And these are invalid variable names:

```crystal
myBadNamedVar = 1
wrong_Name = 2
```

## YAML configuration example

```yaml
Naming/VariableNames:
  Enabled: true
```
