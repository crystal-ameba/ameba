# `Typing/MethodParameterTypeRestriction`

A rule that enforces method parameters have type restrictions, with optional enforcement of block parameters.

For example, this is considered invalid:

```crystal
def add(a, b)
  a + b
end
```

And this is considered valid:

```crystal
def add(a : String, b : String)
  a + b
end
```

When the config options `PrivateMethods` and `ProtectedMethods`
are true, this rule is also applied to private and protected methods, respectively.

The `NodocMethods` configuration option controls whether this rule applies to
methods with a `:nodoc:` directive.

The `BlockParameters` configuration option will extend this to block parameters, where these are invalid:

```crystal
def exec(&)
end

def exec(&block)
end
```

And this is valid:

```crystal
def exec(&block : String -> String)
  yield "cmd"
end
```

The config option `DefaultValue` controls whether this rule applies to parameters that have a default value.

## YAML configuration example

```yaml
Typing/MethodParameterTypeRestriction:
  Enabled: true
  DefaultValue: false
  BlockParameters: false
  PrivateMethods: false
  ProtectedMethods: false
  NodocMethods: false
```
