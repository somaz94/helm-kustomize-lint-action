# helm-kustomize-lint-action

[![CI](https://github.com/somaz94/helm-kustomize-lint-action/actions/workflows/ci.yml/badge.svg)](https://github.com/somaz94/helm-kustomize-lint-action/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Latest Tag](https://img.shields.io/github/v/tag/somaz94/helm-kustomize-lint-action)](https://github.com/somaz94/helm-kustomize-lint-action/tags)
[![Top Language](https://img.shields.io/github/languages/top/somaz94/helm-kustomize-lint-action)](https://github.com/somaz94/helm-kustomize-lint-action)
[![GitHub Marketplace](https://img.shields.io/badge/Marketplace-Helm%20Kustomize%20Lint%20Action-blue?logo=github)](https://github.com/marketplace/actions/helm-kustomize-lint-action)

A composite GitHub Action that lints a Helm chart end-to-end in a single step: `yamllint` over chart metadata, `helm lint --strict` per values file, `helm template --debug` render check, and optional `kubeconform` validation of the rendered manifests.

It replaces the shared lint prelude that most Helm chart repos copy-paste (`azure/setup-helm` + `helm lint` + `helm template` for every environment values file, optionally followed by `kubeconform`).

> **Scope**: v1.0.0 is **Helm-only**. The `kustomize` in the action name is reserved for a future `kustomize build` + validation mode (v1.1.0+). The existing inputs will stay backwards-compatible when kustomize support lands.

<br/>

## Features

- One action, whole Helm lint prelude: `setup-helm` → optional `yamllint` on `Chart.yaml` + `values*.yaml` → `helm lint` (per values file) → `helm template --debug` (per values file) → optional `kubeconform` on rendered manifests
- Zero config for a single-chart layout (`Chart.yaml` at repo root with a `values.yaml`)
- Multi-env charts: pass `values_files` as multi-line input — each file is linted and rendered independently (mirrors the `helm lint ./chart -f values-<env>.yaml` pattern)
- Tunable: `chart_path`, `helm_version` (pin or `latest`), `working_directory` for mono-repos, `lint_strict` (default on), `run_yamllint` / `run_template` / `run_kubeconform` toggles, `yamllint_config` override, `kubeconform_version` + `kubeconform_schema_locations` (multi-line) for CRD schema URLs
- Templates are deliberately **not** yamllinted (Helm Go-template syntax is not valid YAML) — `run_yamllint` only touches `Chart.yaml` + `values*.yaml`
- Writes a per-run summary table to `$GITHUB_STEP_SUMMARY`
- Exposes `lint_result`, `template_result`, `kubeconform_result` outputs (`success` / `failure` / `skipped`) — readable even when the action fails with `continue-on-error: true`

<br/>

## Requirements

- **Runner OS**: `ubuntu-latest` is the tested target. `sudo install` is used to place `kubeconform` under `/usr/local/bin`, which GitHub-hosted Ubuntu runners allow without extra setup.
- **Caller must run `actions/checkout`** before this action so the chart directory is on disk.
- **Helm** is installed by the action via `azure/setup-helm@v5` — no pre-install required.
- **kubeconform** (opt-in) is downloaded from the official GitHub releases when `run_kubeconform: true`. Supports `linux/amd64` and `linux/arm64`.
- **Python** (for `yamllint`) is provided by GitHub-hosted runners. If `run_yamllint: true`, the action installs `yamllint` via `pip` at runtime.

<br/>

## Quick Start

Drop this into `.github/workflows/lint.yml` of any Helm chart repo:

```yaml
name: Lint

on:
  pull_request:
  push:
    branches: [main]

permissions:
  contents: read

jobs:
  helm-lint:
    name: Helm Lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - uses: somaz94/helm-kustomize-lint-action@v1
```

With all defaults it runs: `setup-helm@v5` with `latest` → `yamllint -d relaxed Chart.yaml values.yaml` → `helm lint . --strict` → `helm template ci-render . --debug > /dev/null`. `kubeconform` is opt-in and stays skipped unless `run_kubeconform: 'true'`.

<br/>

## Usage

### Multi-env values files

```yaml
- uses: actions/checkout@v6
- uses: somaz94/helm-kustomize-lint-action@v1
  with:
    chart_path: ./helm
    values_files: |
      values-aws.yaml
      values-gcp.yaml
      values-cloudflare.yaml
```

Each file is linted and rendered in its own helm invocation, so an error in one env doesn't mask another. The aggregate `lint_result` / `template_result` is `failure` if **any** file fails.

<br/>

### Opt into kubeconform with CRD schemas

```yaml
- uses: actions/checkout@v6
- uses: somaz94/helm-kustomize-lint-action@v1
  with:
    run_kubeconform: 'true'
    kubeconform_schema_locations: |
      default
      https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json
```

The action pipes `helm template` output into `kubeconform -strict -ignore-missing-schemas -summary` with one `-schema-location` flag per non-empty line. The `default` location is the bundled Kubernetes schema set; extra lines add CRD schemas (e.g., Gateway API, Prometheus Operator via the datreeio catalog).

<br/>

### Pin helm version for reproducibility

```yaml
- uses: actions/checkout@v6
- uses: somaz94/helm-kustomize-lint-action@v1
  with:
    helm_version: v3.16.4
```

Default is `latest`. Pin when you need a specific helm for consistent `helm lint` warning behavior across PRs.

<br/>

### Monorepo with chart in a subdirectory

```yaml
- uses: actions/checkout@v6
- uses: somaz94/helm-kustomize-lint-action@v1
  with:
    working_directory: charts/my-app
    values_files: |
      values.yaml
      values-staging.yaml
```

All helm / yamllint / kubeconform commands run from `working_directory`. Paths in `values_files` are relative to `working_directory`.

<br/>

### Skip `helm template` (lint-only, fast mode)

```yaml
- uses: actions/checkout@v6
- uses: somaz94/helm-kustomize-lint-action@v1
  with:
    run_template: 'false'
```

`template_result` becomes `skipped`. Useful when you render elsewhere (e.g., Argo CD) and only need `helm lint` as a guardrail.

<br/>

### Disable `--strict` for legacy charts

```yaml
- uses: actions/checkout@v6
- uses: somaz94/helm-kustomize-lint-action@v1
  with:
    lint_strict: 'false'
```

Default is `true`. Flip off when adopting the action against a legacy chart you can't immediately fix — warnings are still emitted, just not promoted to errors.

<br/>

### Provide a custom yamllint config

```yaml
- uses: actions/checkout@v6
- uses: somaz94/helm-kustomize-lint-action@v1
  with:
    yamllint_config: .yamllint.yml
```

When empty (default), the action uses `yamllint -d relaxed`. When set, it uses `yamllint -c <config>`. The config path is relative to `working_directory`.

<br/>

### Consume the outputs in downstream steps

```yaml
- id: lint
  uses: somaz94/helm-kustomize-lint-action@v1
  continue-on-error: true
  with:
    run_kubeconform: 'true'

- name: Report lint result
  run: |
    echo "lint=${{ steps.lint.outputs.lint_result }}"
    echo "template=${{ steps.lint.outputs.template_result }}"
    echo "kubeconform=${{ steps.lint.outputs.kubeconform_result }}"
    if [[ "${{ steps.lint.outputs.lint_result }}" == "failure" ]]; then
      echo "::warning::helm lint failed — review the rendered output above"
    fi
```

`continue-on-error: true` lets the workflow inspect the outputs before deciding whether to fail the job.

<br/>

## Inputs

| Input | Required | Default | Description |
|---|---|---|---|
| `chart_path` | no | `.` | Path to the Helm chart directory (the one containing `Chart.yaml`), relative to `working_directory`. |
| `values_files` | no | `''` (multiline) | Multi-line list of values files (one path per line, relative to `working_directory`). Empty means lint/template once with the chart's default `values.yaml`. |
| `helm_version` | no | `latest` | Helm version passed to `azure/setup-helm`. Use `latest` or a pinned tag such as `v3.16.4`. |
| `working_directory` | no | `.` | Base directory to run all helm/yamllint/kubeconform commands from. |
| `lint_strict` | no | `true` | When `true`, pass `--strict` to `helm lint` so warnings are treated as errors. |
| `run_yamllint` | no | `true` | When `true`, run yamllint on `Chart.yaml` and `values*.yaml` before helm lint. Templates are skipped (Go-template, not plain YAML). |
| `yamllint_config` | no | `''` | Path to a yamllint config file (e.g., `.yamllint.yml`). Empty uses the built-in `relaxed` profile. |
| `run_template` | no | `true` | When `true`, run `helm template --debug` for each values file to catch rendering errors. |
| `run_kubeconform` | no | `false` | When `true`, pipe `helm template` output through kubeconform to validate rendered manifests against Kubernetes schemas. Opt-in. |
| `kubeconform_version` | no | `v0.6.7` | kubeconform release tag (e.g., `v0.6.7`). Only used when `run_kubeconform` is `true`. |
| `kubeconform_schema_locations` | no | `default` (multiline) | Multi-line list of kubeconform `-schema-location` values. Use `default` for the bundled Kubernetes schemas; add extra lines (e.g., datreeio CRD catalog URLs) for CRD coverage. |

<br/>

## Outputs

| Output | Values | Description |
|---|---|---|
| `lint_result` | `success` / `failure` | Result of the helm lint phase. `success` when every chart/values combination lints cleanly, otherwise `failure`. Populated even when the action fails (use with `continue-on-error`). |
| `template_result` | `success` / `failure` / `skipped` | Result of the helm template phase. `skipped` when `run_template: 'false'`. |
| `kubeconform_result` | `success` / `failure` / `skipped` | Result of the kubeconform phase. `skipped` when `run_kubeconform: 'false'` (default). |

<br/>

## Permissions

This action only reads the checkout and writes to `$GITHUB_STEP_SUMMARY`. A minimal `permissions: contents: read` at the job or workflow level is sufficient.

<br/>

## How It Works

1. **Validate inputs** — checks that `chart_path` contains `Chart.yaml`, every `values_files` entry exists, and `kubeconform_version` matches a valid release tag when opt-in.
2. **`azure/setup-helm@v5`** — installs helm at the requested version.
3. **yamllint** (`run_yamllint: true`) — pip-installs yamllint, then lints only `Chart.yaml` + `values*.yaml` (templates are Go-template and would produce noise).
4. **Helm lint** — loops over `values_files` (or runs once with chart defaults when empty); aggregate result drives the `lint_result` output.
5. **Helm template** — same loop shape with `--debug`; output discarded. Drives `template_result` (or `skipped`).
6. **Kubeconform** (`run_kubeconform: true`) — downloads the pinned kubeconform binary (multi-arch), then pipes `helm template` output through `kubeconform -strict -ignore-missing-schemas -summary` with the configured `-schema-location` args. Drives `kubeconform_result` (or `skipped`).
7. **Summary** — a markdown table is appended to `$GITHUB_STEP_SUMMARY` on `if: always()` so failed runs still surface what was attempted.

See [CLAUDE.md](CLAUDE.md) for the full internal flow and the composite-output wiring rationale.

<br/>

## License

MIT. See [LICENSE](LICENSE).
