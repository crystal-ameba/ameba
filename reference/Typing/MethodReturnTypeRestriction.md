# `Typing/MethodReturnTypeRestriction`

A rule that enforces method definitions have a return type restriction.

For example, this are considered invalid:

```crystal
def hello(name = "World")
  "Hello #{name}"
end
```

And this is valid:

```crystal
def hello(name = "World") : String
  "Hello #{name}"
end
```

When the config options `PrivateMethods` and `ProtectedMethods`
are true, this rule is also applied to private and protected methods, respectively.

The `NodocMethods` configuration option controls whether this rule applies to
methods with a `:nodoc:` directive.

## YAML configuration example

```yaml
Typing/MethodReturnTypeRestriction:
  Enabled: true
  PrivateMethods: false
  ProtectedMethods: false
  NodocMethods: false
```
