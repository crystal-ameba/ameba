<p align="center">
  <img src="https://gitcdn.link/repo/veelenga/bin/master/ameba/logo.png" width="200">
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

See also [Roadmap](https://github.com/veelenga/ameba/wiki).

## Usage

Run `ameba` binary within your project directory to catch code issues:

```sh
$ ameba
Inspecting 107 files.

...............F.....................F....................................................................

src/ameba/rule/unneeded_disable_directive.cr:29:7
Lint/UselessAssign: Useless assignment to variable `s`

src/ameba/formatter/flycheck_formatter.cr:5:21
Lint/UnusedArgument: Unused argument `location`

Finished in 248.9 milliseconds

107 inspected, 2 failures.

```

## Installation

### As a project dependency:

Add this to your application's `shard.yml`:

```yaml
development_dependencies:
  ameba:
    github: veelenga/ameba
    version: 0.7.0
```

Build `bin/ameba` binary within your project directory while running `shards install`.

You may also want to use it on [Travis](travis-ci.org):

```yaml
# .travis.yml
language: crystal
install:
  - shards install
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

## Configuration

Default configuration file is `.ameba.yml`.
It allows to configure rule properties, disable specific rules and exclude sources from the rules.

Generate new file by running `ameba --gen-config`.

### Inline disabling

One or more rules can be disabled using inline directives:

```crystal
# ameba:disable Style/LargeNumbers
time = Time.epoch(1483859302)

time = Time.epoch(1483859302) # ameba:disable Style/LargeNumbers
```

## Editor integration

 * Vim: [vim-crystal](https://github.com/rhysd/vim-crystal) (via [Syntastic](https://github.com/vim-syntastic/syntastic))
 * Emacs: [ameba.el](https://github.com/veelenga/ameba.el)
 * Sublime Text: [Sublime Linter Ameba](https://github.com/epergo/SublimeLinter-contrib-ameba)

## Credits & inspirations

- [Crystal Language](crystal-lang.org)
- [Rubocop](http://rubocop.readthedocs.io/en/latest/)
- [Credo](http://credo-ci.org/)
- [Dogma](https://github.com/lpil/dogma)

## Contributors

- [veelenga](https://github.com/veelenga) Vitalii Elenhaupt - creator, maintainer
