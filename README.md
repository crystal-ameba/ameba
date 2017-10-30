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
Inspecting 7 files.


..F...F

7 inspected, 2 failures.

src/ameba/formatter.cr:47
LineLength: Line too long [122]

src/ameba.cr:18
LineLength: Line too long [81]
```

## Contributing

1. Fork it ( https://github.com/veelenga/ameba/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [veelenga](https://github.com/veelenga) Vitalii Elenhaupt - creator, maintainer
