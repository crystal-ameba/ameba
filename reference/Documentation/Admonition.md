# `Documentation/Admonition`

A rule that reports documentation admonitions.

Optionally, these can fail at an appropriate time.

```crystal
def get_user(id)
  # TODO(2024-04-24) Fix this hack when the database migration is complete
  if id < 1_000_000
    v1_api_call(id)
  else
    v2_api_call(id)
  end
end
```

`TODO` comments are used to remind yourself of source code related things.

The premise here is that `TODO` should be dealt with in the near future
and are therefore reported by Ameba.

`FIXME` comments are used to indicate places where source code needs fixing.

The premise here is that `FIXME` should indeed be fixed as soon as possible
and are therefore reported by Ameba.

## YAML configuration example

```yaml
Documentation/Admonition:
  Enabled: true
  Admonitions: [TODO, FIXME, BUG]
  Timezone: UTC
```
