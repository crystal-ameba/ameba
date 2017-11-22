<p align="center">
  <img src="https://media.githubusercontent.com/media/veelenga/bin/master/ameba/logo.png" width="200">
  <h3 align="center">Ameba</h3>
  <p align="center">Code style linter for Crystal<p>
  <p align="center">
    <sup>
      <i> (a single-celled animal that catches food and moves about by extending fingerlike projections of protoplasm) </i>
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

Ameba is a static code analysis tool for the Crystal language.
It enforces a consistent [Crystal code style](https://crystal-lang.org/docs/conventions/coding_style.html),
also catches code smells and wrong code constructions.

## How it works

Ameba's *"fingerlike projections"* are [rules](src/ameba/rule/). Each rule makes the inspection for that or
another problem in the source code. Currently rules are able to:

- [x] simply validate lines of source code
- [x] traverse AST using [`Crystal::Visitor`](https://github.com/crystal-lang/crystal/blob/1f3e8b0e742b55c1feb5584dc932e87034365f48/src/compiler/crystal/syntax/visitor.cr)
- [x] tokenize sources using [`Crystal::Lexer`](https://github.com/crystal-lang/crystal/blob/1f3e8b0e742b55c1feb5584dc932e87034365f48/src/compiler/crystal/syntax/lexer.cr) and iterate through tokens
- [ ] do semantics analysis using [`Crystal::SemanticVisitor`](https://github.com/crystal-lang/crystal/blob/master/src/compiler/crystal/semantic/semantic_visitor.cr)

## Installation

### As a project dependency:

Add this to your application's `shard.yml`:

```yaml
development_dependencies:
  ameba:
    github: veelenga/ameba
```

Build `bin/ameba` binary within your project directory while running `crystal deps`.

You may also want to use it on [Travis](travis-ci.org):

```yaml
# .travis.yml
language: crystal
install:
  - crystal deps
script:
  - crystal spec
  - bin/ameba
```

Using this config Ameba will inspect files just after the specs run. Travis will also fail
the build if some problems detected.

### OS X

```sh
$ brew tap veelenga/tap
$ brew install ameba
```

### From sources

```sh
$ git clone https://github.com/veelenga/ameba && cd ameba
$ make install
```

## Usage

Run `ameba` binary within your project directory to catch code issues:

```
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

Default configuration file is `.ameba.yml`.
It allows to configure or even disable specific rules.
Simply copy and adjust [existed sample](config/ameba.yml).
Each rule is enabled by default, even if you remove it from the config file.

## Writing a new Rule

Adding a new rule is as simple as inheriting from `Ameba::Rule::Base` struct and implementing
a logic to detect a problem in the source file:

```crystal
struct MySuperRule < Ameba::Rule::Base
  # This is a required method to be implemented by the rule.
  # Source will be passed here. If rule detects an issue in the source,
  # it reports an error:
  #
  #   source.error rule, location, message
  #
  def test(source)
    # TODO: test source
  end
end

```

As soon as a custom rule is defined, it becomes available in a full set of rules
executed by default and also can be configured via config file:

```yaml
MySuperRule:
  Enabled: false
```

## Credits & inspirations

- [Crystal Language](crystal-lang.org)
- [Rubocop](http://rubocop.readthedocs.io/en/latest/)
- [Credo](http://credo-ci.org/)
- [Dogma](https://github.com/lpil/dogma)

## Contributors

- [veelenga](https://github.com/veelenga) Vitalii Elenhaupt - creator, maintainer
