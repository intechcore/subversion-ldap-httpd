# Contributing

Issues and pull requests are welcome.

## Build and test

```sh
make build   # build the image
make test    # build and run the integration tests
make lint    # shellcheck + hadolint
make scan    # build + trivy vulnerability scan
```

CI runs for every pull request: ShellCheck, Hadolint, actionlint, zizmor, `trivy config` and the
contract check, the integration tests on amd64 and arm64, and a Trivy scan of the image.

The image ships no shell code of its own, only configuration, so there is no line coverage to
measure. `tests/contract.sh` checks that every feature and configuration path in the README has a
test instead.

## Pull requests

1. Branch from the default branch as `type/description`, for example `fix/empty-title`.
2. Keep one change per pull request. New behavior comes with tests; a bug fix adds a test that
   fails without it.
3. Write commit messages as [Conventional Commits](https://www.conventionalcommits.org/) without a
   scope: `feat: ...`, `fix: ...`, `docs: ...`, `refactor: ...`, `test: ...`, `build: ...`,
   `ci: ...`, `chore: ...`.
4. Sign your commits. The default branch accepts verified signatures only.
5. Add an entry under `## [Unreleased]` in `CHANGELOG.md`, written for users: the release notes
   quote it. Update the README when behavior or configuration changes.

Pull requests are squash-merged once all required checks are green.

## Releases

Releases are automatic when an input changes. The notes take the Unreleased entries added since
the previous release, see `.github/scripts/release-notes.sh`.

## Changelog

1. Keep one `## [Unreleased]` section on top, and add every entry there.
2. Do not cut per-release sections. The release notes pick the new entries by themselves.
3. Entries from before the automatic releases stay under `## History before automatic releases`.
