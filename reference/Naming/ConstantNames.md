# `Naming/ConstantNames`

A rule that enforces constant names to be in screaming case.

For example, these constant names are considered valid:

```crystal
LUCKY_NUMBERS     = [3, 7, 11]
DOCUMENTATION_URL = "http://crystal-lang.org/docs"
```

And these are invalid names:

```crystal
myBadConstant = 1
Wrong_NAME = 2
```

## YAML configuration example

```yaml
Naming/ConstantNames:
  Enabled: true
```
