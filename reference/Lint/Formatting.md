# `Lint/Formatting`

A rule that verifies syntax formatting according to the
Crystal's built-in formatter.

For example, this syntax is invalid:

    def foo(a,b,c=0)
      #foobar
      a+b+c
    end

And should be properly written:

    def foo(a, b, c = 0)
      # foobar
      a + b + c
    end

## YAML configuration example

```yaml
Lint/Formatting:
  Enabled: true
  FailOnError: false
```
