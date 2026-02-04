# `Naming/AccessorMethodName`

A rule that makes sure that accessor methods are named properly.

Favour this:

```crystal
class Foo
  def user
    @user
  end

  def user=(value)
    @user = value
  end
end
```

Over this:

```crystal
class Foo
  def get_user
    @user
  end

  def set_user(value)
    @user = value
  end
end
```

## YAML configuration example

```yaml
Naming/AccessorMethodName:
  Enabled: true
```
