# Contributing to Ameba

First off, thank you for considering contributing to Ameba! 🎉

We're thrilled to have you here. Every contribution — whether it's a bug report, a typo fix, a new rule, or a docs improvement — helps make the Crystal ecosystem better for everyone.

## Where to start

- **New to the project?** Check out issues labeled
  [`good first issue`](https://github.com/crystal-ameba/ameba/labels/good%20first%20issue)
  or [`help wanted`](https://github.com/crystal-ameba/ameba/labels/help%20wanted).
- **Got an idea?** Open a [discussion](https://github.com/crystal-ameba/ameba/discussions)
  or an [issue](https://github.com/crystal-ameba/ameba/issues/new/choose) first
  so we can align on direction before you invest too much time.
- **Found a bug?** [Open an issue](https://github.com/crystal-ameba/ameba/issues/new/choose)
  with a minimal reproduction. If you'd like to fix it yourself, that's
  even better — let us know in the issue so we can avoid duplicate work.

## Setting up the project

```sh
git clone https://github.com/crystal-ameba/ameba
cd ameba
make # builds the binary into bin/ameba
```

> [!NOTE]
> Ameba uses [Crystal](https://crystal-lang.org) (≥ 1.19)
> and [Shards](https://github.com/crystal-lang/shards).
> Make sure both are installed.

## Running tests and linter

```sh
make spec # run the spec suite
make lint # run Ameba on its own code
make test # spec + lint
```

Individual spec files can be run with:

```sh
crystal spec spec/path/to/file_spec.cr
```

## Making a change

1. **Fork** the repository and create a branch off `master`.
2. **Make your changes** — keep them focused and consistent with the existing code style.
3. **Write or update tests** to cover your changes. We use the standard Crystal testing framework.
4. **Run `make test`** and make sure everything passes.
5. **Run `ameba --fix`** to let Ameba autocorrect any style issues before committing.
6. **Open a pull request** against `master` with a clear title and description. Reference the related issue if applicable.

> [!TIP]
> **New to rules?** Each rule lives under `src/ameba/rule/<group>/`.
> Have a look at an existing rule to get a feel for the pattern.
> There's also a spec companion under `spec/ameba/rule/<group>/`.

## Code style

Ameba enforces its own rules on its codebase. Run `make lint` and `ameba --fix` to stay in line. When in doubt, match the style of the code you're editing.

## Pull request checklist

- [ ] Changes are limited to a single concern (one feature / fix per PR).
- [ ] New code is covered by tests.
- [ ] Tests pass (`make test`).
- [ ] Ameba is happy (`make lint`).
- [ ] Commit messages are descriptive (e.g. `Fix off-by-one in Metrics/MethodLength`).

## Getting help

If you get stuck, don't hesitate to ask:

- Open a [discussion](https://github.com/crystal-ameba/ameba/discussions) on GitHub.
- Reach out on the [Crystal community chat](https://crystal-lang.org/community/).

## Code of conduct

All contributors are expected to uphold a respectful environment.
Be kind, assume good intent, and give constructive feedback.

## License

By contributing to Ameba, you agree that your contributions will be licensed under the [MIT License](LICENSE).
