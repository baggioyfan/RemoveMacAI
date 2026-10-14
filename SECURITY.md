# Security policy

## Reporting a vulnerability

Please don't open a public issue for a security problem. Report it privately: open the repository's Security tab and click "Report a vulnerability". Include your macOS version, the output of `removemacai --version` and the steps to reproduce it.

## Supported versions

Fixes go into new releases only, so check that you're on the latest one before reporting.

## Installing

The one-line installer downloads the latest release, checks it against the SHA-256 checksum published with that release and stops if they don't match. It runs the binary from a temporary directory and deletes it afterwards. You can read [install.sh](install.sh) before running it, or install with Homebrew instead:

```sh
brew install omlahore/tap/removemacai
```
