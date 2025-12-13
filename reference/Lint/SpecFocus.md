# `Lint/SpecFocus`

Checks if specs are focused.

In specs `focus: true` is mainly used to focus on a spec
item locally during development. However, if such change
is committed, it silently runs only focused spec on all
other environment, which is undesired.

This is considered bad:

```crystal
describe MyClass, focus: true do
end

describe ".new", focus: true do
end

context "my context", focus: true do
end

it "works", focus: true do
end
```

And it should be written as the following:

```crystal
describe MyClass do
end

describe ".new" do
end

context "my context" do
end

it "works" do
end
```

## YAML configuration example

```yaml
Lint/SpecFocus:
  Enabled: true
```
