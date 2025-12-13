# `Naming/RescuedExceptionsVariableName`

A rule that makes sure that rescued exceptions variables are named as expected.

For example, these are considered valid:

    def foo
      # potentially raising computations
    rescue e
      Log.error(exception: e) { "Error" }
    end

And these are invalid variable names:

    def foo
      # potentially raising computations
    rescue wtf
      Log.error(exception: wtf) { "Error" }
    end

## YAML configuration example

```yaml
Naming/RescuedExceptionsVariableName:
  Enabled: true
  AllowedNames: [e, ex, exception, error]
```
