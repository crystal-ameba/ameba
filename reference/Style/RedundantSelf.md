# `Style/RedundantSelf`

A rule that disallows redundant uses of `self`.

This is considered bad:

```crystal
class Greeter
  getter name : String

  def self.init
    self.new("Crystal").greet
  end

  def initialize(@name)
  end

  def greet
    puts "Hello, my name is #{self.name}"
  end

  self.init
end
```

And needs to be written as:

```crystal
class Greeter
  getter name : String

  def self.init
    new("Crystal").greet
  end

  def initialize(@name)
  end

  def greet
    puts "Hello, my name is #{name}"
  end

  init
end
```

## YAML configuration example

```yaml
Style/RedundantSelf:
  Enabled: true
  AllowedMethodNames:
    - in?
    - inspect
    - not_nil!
```
