# Security Policy

## Supported versions

Only the latest release on the [Releases page](https://github.com/drlholloway/fretboardtrainer/releases)
and the current App Store / Play Store build receive fixes. Upgrade before reporting.

## What counts

Fretboard Trainer runs entirely on your phone or computer. It has no accounts,
no network calls beyond opening the tip link in your browser, and no telemetry.
Settings and lesson progress are stored locally. The interesting surface is:

- The release pipeline: how builds are produced, signed and published.
- Dependencies pulled in through pub, Gradle and GitHub Actions.
- Anything that lets the app do more than show questions on screen.

Crashes from odd settings or progress data are ordinary bugs unless they lead
to something beyond a crash.

## Reporting a vulnerability

Please do not open a public issue for a security problem. Use GitHub's private
reporting instead: **Security → Report a vulnerability** on the repository, or
https://github.com/drlholloway/fretboardtrainer/security/advisories/new

Include the version, platform, what you observed and how to reproduce it. You
will get an acknowledgement within a week. Fixes ship as a new release with a
credit in the changelog unless you prefer to stay anonymous.

## Dependencies

Dependabot watches the Dart, Gradle and GitHub Actions dependencies weekly and
CodeQL scans the repository on every push. Security fixes that arrive through
dependency updates are called out in `CHANGELOG.md` under the affected release.
