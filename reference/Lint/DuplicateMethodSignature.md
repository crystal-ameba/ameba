# `Lint/DuplicateMethodSignature`

Reports repeated class or module method signatures.

Only methods of the same signature are considered duplicates,
regardless of their bodies, except for ones including `previous_def`.

```crystal
class Foo
  def greet(name)
    puts "Hello #{name}!"
  end

  def greet(name) # duplicated method signature
    puts "¡Hola! #{name}"
  end
end
```

## YAML configuration example

```yaml
Lint/DuplicateMethodSignature:
  Enabled: true
```
