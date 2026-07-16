# Touchdown free CI standard

This repository is the single source of truth for zero-dollar GitHub Actions
inside the Touchdown-Labs organization. It also exposes the organization's
workflow template for new repositories.

The standard:

- runs only on [self-hosted, touchdown-ci];
- skips pull requests from forks;
- rejects inherited provider and deployment secrets;
- uses a sanitized, repository-scoped runner process;
- uploads no Actions cache or artifact;
- writes a hash-bound receipt to the local evidence directory; and
- pins the official GitHub runner archive and checkout action.

## Add the workflow to a repository

Create .github/workflows/touchdown-free-ci.yml:

~~~yaml
name: Touchdown Free CI

on:
  pull_request:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read

jobs:
  free-ci:
    uses: Touchdown-Labs/.github/.github/workflows/free-ci.yml@v1
    with:
      profile: custom
      ci_script: .github/touchdown-ci.sh
~~~

Put that repository's real, offline release gate in
.github/touchdown-ci.sh. The central workflow does not guess whether a
repository is Python, Node, Swift, CUDA, or mixed.

Use profile check-only until a repository has an explicit CI contract. That
profile performs Git integrity, whitespace, and shell syntax checks only.

## Start and remove a runner

~~~bash
git clone https://github.com/Touchdown-Labs/.github touchdown-ci-standard
cd touchdown-ci-standard

scripts/touchdown_runner.sh install Touchdown-Labs/REPOSITORY
scripts/touchdown_runner.sh run Touchdown-Labs/REPOSITORY
~~~

After the queued jobs finish, stop the process with Ctrl-C and remove it:

~~~bash
scripts/touchdown_runner.sh remove Touchdown-Labs/REPOSITORY
~~~

Receipts remain under ~/.touchdown/ci-evidence. Runner registrations and
working directories are removed.

## Security boundary

The runner executes as the local macOS user. The clean environment and
isolated home reduce accidental credential exposure; they are not an operating
system sandbox. Only run trusted branches. GitHub specifically recommends
using self-hosted runners with private repositories because public fork pull
requests can execute hostile code.

Official references:

- [Billing for GitHub Actions](https://docs.github.com/en/billing/managing-billing-for-your-products/managing-billing-for-github-actions)
- [Adding self-hosted runners](https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/add-runners)
- [Reusing workflow configurations](https://docs.github.com/en/actions/reference/workflows-and-actions/reusing-workflow-configurations)
