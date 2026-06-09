# `Lint/MissingBlockArgument`

A rule that disallows yielding method definitions without block argument.

For example, this is considered invalid:

    def foo
      yield 42
    end

And has to be written as the following:

    def foo(&)
      yield 42
    end

## YAML configuration example

```yaml
Lint/MissingBlockArgument:
  Enabled: true
```
