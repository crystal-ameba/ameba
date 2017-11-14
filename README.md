<p align="center">
  <img src="https://media.githubusercontent.com/media/veelenga/bin/master/ameba/logo.png" width="200">
  <h3 align="center">Ameba</h3>
  <p align="center">Code style linter for Crystal<p>
  <p align="center">
    <sup>
      <i>
        (a single-celled animal that catches food and moves about by extending fingerlike projections of protoplasm)
      </i>
    </sup>
  </p>
  <p align="center">
    <a href="https://travis-ci.org/veelenga/ameba"><img src="https://travis-ci.org/veelenga/ameba.svg?branch=master"></a>
    <a href="https://github.com/veelenga/ameba/releases"><img src="https://img.shields.io/github/release/veelenga/ameba.svg?maxAge=360"></a>
    <a href="https://shards.rocks/badge/github/veelenga/ameba"><img src="https://shards.rocks/badge/github/veelenga/ameba/status.svg"></a>
    <a href="https://github.com/veelenga/ameba/blob/master/LICENSE"><img src="https://img.shields.io/github/license/veelenga/ameba.svg"></a>
  <a href="https://gitter.im/veelenga/ameba?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge"><img src="https://badges.gitter.im/veelenga/ameba.svg"></a>
  </p>
</p>

## About

Ameba is a tool for enforcing a consistent Crystal code style, for catching code smells and wrong code constructions.
Ameba's [rules](src/ameba/rules/) traverse AST and report bad parts of your code.

Is still under construction, compatibility may be broken :construction:

## Installation

### As a project dependency:

Add this to your application's `shard.yml`:

```yaml
development_dependencies:
  ameba:
    github: veelenga/ameba
```

Compile and install `ameba` binary onto your system while running `crystal deps`.

### OS X

```
$ brew tap veelenga/tap
$ brew install ameba
```

### From sources

```
$ git clone https://github.com/veelenga/ameba && cd ameba
$ make install
```
Or just compile it from sources `make install`.

## Usage

Run `ameba` binary within your project directory to catch code issues:

```sh
$ ameba
Inspecting 52 files.

.........................F.......F........F.........

src/ameba/ast/traverse.cr:27:5
PredicateName: Favour method name 'node?' over 'is_node?'

src/ameba/rules/empty_expression.cr:42:7
LiteralInCondition: Literal value found in conditional

src/ameba/rules/empty_expression.cr:30:7
UnlessElse: Favour if over unless with else

Finished in 10.53 milliseconds

52 inspected, 3 failures.
```

## Configuration

It is possible to configure or even disable specific rules using YAML configuration file.
By default Ameba is looking for `.ameba.yml` in a project root directory.
Copy and adjust [existed example](config/ameba.yml).

## Write a new Rule

Adding a new rule is as simple as inheriting from `Rule::Base` struct and implementing
your logic to detect a problem:

```crystal
struct DebuggerStatement < Rule::Base
  # This is a required method to be implemented by the rule.
  # Source will be passed here. If rule finds an issue in this source,
  # it reports an error: 
  # 
  #   source.error rule, line_number, message
  #
  def test(source)
    # This line deletegates verification to a particular AST visitor.
    AST::Visitor.new self, source
  end

  # This method is called once the visitor finds a required node.
  def test(source, node : Crystal::Call)
    # It reports an error, if there is `debugger` method call
    # without arguments and a receiver. That's it, somebody forgot
    # to remove a debugger statement.
    return unless node.name == "debugger" && node.args.empty? && node.obj.nil?

    source.error self, node.location,
      "Possible forgotten debugger statement detected"
  end
end

```

## Contributors

- [veelenga](https://github.com/veelenga) Vitalii Elenhaupt - creator, maintainer
