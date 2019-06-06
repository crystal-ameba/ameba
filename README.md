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

src/ameba/formatter/flycheck_formatter.cr:4:33
[W] Lint/UnusedArgument: Unused argument `location`
> source.issues.each do |e, location|
                            ^

src/ameba/formatter/base_formatter.cr:12:7
[W] Lint/UselessAssign: Useless assignment to variable `s`
> return s += issues.size
         ^

Finished in 542.64 milliseconds

129 inspected, 2 failures.

```

## Installation

### As a project dependency:

Add this to your application's `shard.yml`:

```yaml
development_dependencies:
  ameba:
    github: veelenga/ameba
    version: ~> 0.10.0
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

### Docker

Build the image:

```sh
$ docker build -t ameba/ameba .
```

To use the resulting image on a local source folder, mount the current (or target) directory into `/src`:

```sh
$ docker run -v $(pwd):/src ameba/ameba
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

### Only/Except

One or more rules, or a one or more group of rules can be included or excluded
via command line arguments:

```
$ ameba --only   Lint/Syntax # runs only Lint/Syntax rule
$ ameba --only   Style,Lint  # runs only rules from Style and Lint groups
$ ameba --except Lint/Syntax # runs all rules except Lint/Syntax
$ ameba --except Style,Lint  # runs all rules except rules in Style and Lint groups
```

### Explanation

Ameba allows you to dig deeper into an issue, by showing you details about the issue
and the reasoning by it being reported.

To be convenient, you can just copy-paste the `PATH:line:column` string from the
report and paste behind the `ameba` command to check it out.

```
$ ameba crystal/command/format.cr:26:83           # show explanation for the issue
$ ameba --explain crystal/command/format.cr:26:83 # same thing
```

### Inline disabling

One or more rules or one or more group of rules can be disabled using inline directives:

```crystal
# ameba:disable Style/LargeNumbers
time = Time.epoch(1483859302)

time = Time.epoch(1483859302) # ameba:disable Style/LargeNumbers, Lint/UselessAssign

time = Time.epoch(1483859302) # ameba:disable Style, Lint
```

## Editor integration

 * Vim: [vim-crystal](https://github.com/rhysd/vim-crystal), [Ale](https://github.com/w0rp/ale)
 * Emacs: [ameba.el](https://github.com/veelenga/ameba.el)
 * Sublime Text: [Sublime Linter Ameba](https://github.com/epergo/SublimeLinter-contrib-ameba)
 * VSCode: [vscode-crystal-ameba](https://github.com/veelenga/vscode-crystal-ameba)

## Credits & inspirations

- [Crystal Language](crystal-lang.org)
- [Rubocop](http://rubocop.readthedocs.io/en/latest/)
- [Credo](http://credo-ci.org/)
- [Dogma](https://github.com/lpil/dogma)

## Contributors

- [veelenga](https://github.com/veelenga) Vitalii Elenhaupt - creator, maintainer
