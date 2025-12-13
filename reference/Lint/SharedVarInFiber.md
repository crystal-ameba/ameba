# `Lint/SharedVarInFiber`

A rule that disallows using shared variables in fibers,
which are mutated during iterations.

In most cases it leads to unexpected behaviour and is undesired.

For example, having this example:

```crystal
n = 0
channel = Channel(Int32).new

while n < 3
  n = n + 1
  spawn { channel.send n }
end

3.times { puts channel.receive } # => # 3, 3, 3
```

The problem is there is only one shared between fibers variable `n`
and when `channel.receive` is executed its value is `3`.

To solve this, the code above needs to be rewritten to the following:

```crystal
n = 0
channel = Channel(Int32).new

while n < 3
  n = n + 1
  m = n
  spawn do { channel.send m }
end

3.times { puts channel.receive } # => # 1, 2, 3
```

This rule is able to find the shared variables between fibers, which are mutated
during iterations. So it reports the issue on the first sample and passes on
the second one.

There are also other techniques to solve the problem above which are
[officially documented](https://crystal-lang.org/reference/guides/concurrency.html)

## YAML configuration example

```yaml
Lint/SharedVarInFiber:
  Enabled: true
```
