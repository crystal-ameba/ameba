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
    <a href="https://travis-ci.org/veelenga/ameba"><img src="https://img.shields.io/travis/veelenga/ameba.svg?maxAge=360"></a>
    <a href="https://github.com/veelenga/ameba/releases"><img src="https://img.shields.io/github/release/veelenga/ameba.svg?maxAge=360"></a>
    <a href="https://shards.rocks/badge/github/veelenga/ameba"><img src="https://shards.rocks/badge/github/veelenga/ameba/status.svg"></a>
    <a href="https://github.com/veelenga/ameba/blob/master/LICENSE"><img src="https://img.shields.io/github/license/mashape/apistatus.svg"></a>
  </p>
</p>

## Status

**CONSTRUCTION ZONE** :construction:

## Installation

Add this to your application's `shard.yml`:

```yaml
development_dependencies:
  ameba:
    github: veelenga/ameba
```

## Usage

```crystal
require "ameba"

Ameba.run
```

```sh
Inspecting 18 files.


...............F.F

18 inspected, 2 failures.

src/ameba/source.cr:26
LineLength: Line too long (82 symbols)

src/ameba.cr:12
UnlessElse: Favour if over unless with else
```

## Contributing

1. Fork it ( https://github.com/veelenga/ameba/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [veelenga](https://github.com/veelenga) Vitalii Elenhaupt - creator, maintainer
