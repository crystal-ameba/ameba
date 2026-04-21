# `Lint/SpecEqWithBoolOrNilLiteral`

Reports `eq(true|false|nil)` expectations in specs.

This is considered bad:

```crystal
it "works" do
  foo.is_a?(String).should eq true
  foo.is_a?(Int32).should eq false
  foo.as?(Symbol).should eq nil
end
```

And it should be written as the following:

```crystal
it "works" do
  foo.is_a?(String).should be_true
  foo.is_a?(Int32).should be_false
  foo.as?(Symbol).should be_nil
end
```

## YAML configuration example

```yaml
Lint/SpecEqWithBoolOrNilLiteral:
  Enabled: true
```
