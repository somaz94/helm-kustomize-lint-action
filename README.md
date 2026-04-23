# helm-kustomize-lint-action

[![CI](https://github.com/somaz94/helm-kustomize-lint-action/actions/workflows/ci.yml/badge.svg)](https://github.com/somaz94/helm-kustomize-lint-action/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Latest Tag](https://img.shields.io/github/v/tag/somaz94/helm-kustomize-lint-action)](https://github.com/somaz94/helm-kustomize-lint-action/tags)
[![Top Language](https://img.shields.io/github/languages/top/somaz94/helm-kustomize-lint-action)](https://github.com/somaz94/helm-kustomize-lint-action)
[![GitHub Marketplace](https://img.shields.io/badge/Marketplace-Helm%20Kustomize%20Lint%20Action-blue?logo=github)](https://github.com/marketplace/actions/helm-kustomize-lint-action)

A composite GitHub Action that lints a Helm chart end-to-end in a single step: `yamllint` over chart metadata, `helm lint --strict` per values file, `helm template --debug` render check, and optional `kubeconform` validation of the rendered manifests.

It replaces the shared lint prelude that most Helm chart repos copy-paste (`azure/setup-helm` + `helm lint` + `helm template` for every environment values file, optionally followed by `kubeconform`).

> **Scope**:
> - `v1.0.x` — Helm single-chart linting (`chart_path` + `values_files`).
> - `v1.1.0+` — adds `mode: changed-charts` for Helm monorepos: runs `ct list-changed` + `ct lint` on charts changed vs `base_ref`, then loops `helm template` and optional `kubeconform` over the changed chart set.
> - `v1.2.0+` — Kustomize mode (`kustomize build` + validation) is still reserved. The existing inputs stay backwards-compatible when it lands.

<br/>

## Features

- Two modes driven by `mode` input:
  - **`helm`** (default): single-chart pipeline — `setup-helm` → optional `yamllint` on `Chart.yaml` + `values*.yaml` → `helm lint` per values file → `helm template --debug` per values file → optional `kubeconform` on rendered manifests. Zero config for a single-chart layout.
  - **`changed-charts`**: monorepo pipeline — installs `chart-testing` → `ct list-changed` against `base_ref` → if any charts changed, `ct lint` (with `--check-version-increment`) + `helm template` + optional `kubeconform`, all scoped to the changed chart set. `skipped` on every output when no charts changed.
- Multi-env charts (`helm` mode): pass `values_files` as multi-line input — each file is linted and rendered independently (mirrors the `helm lint ./chart -f values-<env>.yaml` pattern).
- Tunable: `chart_path`, `helm_version` (pin or `latest`), `working_directory` for mono-repos, `lint_strict` (default on), `run_yamllint` / `run_template` / `run_kubeconform` toggles, `yamllint_config` override, `kubeconform_version` + `kubeconform_schema_locations` (multi-line) for CRD schema URLs. `changed-charts` adds `base_ref`, `charts_dir`, `ct_version`, `ct_check_version_increment`.
- Templates are deliberately **not** yamllinted (Helm Go-template syntax is not valid YAML) — `run_yamllint` only touches `Chart.yaml` + `values*.yaml`.
- Writes a per-run summary table to `$GITHUB_STEP_SUMMARY`.
- Exposes `lint_result`, `template_result`, `kubeconform_result`, `changed_charts_count` outputs — readable even when the action fails with `continue-on-error: true`.

<br/>

## Requirements

- **Runner OS**: `ubuntu-latest` is the tested target. `sudo install` is used to place `kubeconform` / `ct` under `/usr/local/bin`, which GitHub-hosted Ubuntu runners allow without extra setup.
- **Caller must run `actions/checkout`** before this action so the chart directory is on disk. For `mode: changed-charts`, also pass **`fetch-depth: 0`** so `ct list-changed` can diff against `base_ref`.
- **Helm** is installed by the action via `azure/setup-helm@v5` — no pre-install required.
- **chart-testing (`ct`)** is downloaded by the action when `mode: changed-charts` is set (from `github.com/helm/chart-testing/releases`, `ct_version`). Supports `linux/amd64` and `linux/arm64`.
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

### Monorepo: lint only charts that changed (`mode: changed-charts`)

For a Helm monorepo (e.g., `charts/{chart-a,chart-b,chart-c}/`) where you only want to lint charts that changed in a PR:

```yaml
name: Lint

on:
  pull_request:
    paths:
      - 'charts/**'

permissions:
  contents: read

jobs:
  lint-changed:
    name: Lint Changed Charts
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
        with:
          fetch-depth: 0        # required — ct list-changed needs full git history
      - uses: somaz94/helm-kustomize-lint-action@v1
        with:
          mode: changed-charts
          charts_dir: charts
          base_ref: ${{ github.event.repository.default_branch }}
          run_kubeconform: 'true'
          kubeconform_schema_locations: |
            default
            https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json
```

What this runs internally:

1. Installs `chart-testing` (`ct_version`, default `v3.11.0`) from its GitHub release.
2. `ct list-changed --target-branch <base_ref> --chart-dirs <charts_dir>` — returns changed chart paths (one per line).
3. If any charts changed: `ct lint --target-branch <base_ref> --chart-dirs <charts_dir> --check-version-increment=true` — `ct` calls `helm lint` internally **and** enforces a `Chart.yaml` version bump per changed chart (disable via `ct_check_version_increment: 'false'`).
4. For each changed chart: `helm template ci-render <chart-path> --debug` (when `run_template: true`, default).
5. For each changed chart: `helm template | kubeconform -strict -ignore-missing-schemas` (when `run_kubeconform: true`).

When no charts are changed (e.g., the PR only touched docs), all three outputs become `skipped` and the action exits 0 — no helm/ct invocations.

In `changed-charts` mode, these inputs are **ignored** (the action emits `::notice::` for each): `chart_path`, `values_files`, `run_yamllint`, `yamllint_config`, `lint_strict` (`ct lint` has no `--strict` flag — it is stricter than `helm lint` by default: validates `Chart.yaml` schema + maintainers + version increment). Use `mode: helm` (default) if you need per-values-file linting.

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
| `mode` | no | `helm` | Operation mode. `helm` (default) lints the chart at `chart_path` with `values_files`. `changed-charts` runs `ct list-changed` + `ct lint` on charts changed under `charts_dir` vs `base_ref` (monorepo). Reserved: `kustomize` (v1.2.0+). |
| `base_ref` | no | `main` | Target branch for `ct list-changed --target-branch` in `changed-charts` mode. Caller **must** run `actions/checkout` with `fetch-depth: 0`. Ignored in `helm` mode. |
| `charts_dir` | no | `charts` | Monorepo charts directory passed to `ct --chart-dirs`. Relative to `working_directory`. Ignored in `helm` mode. |
| `ct_version` | no | `v3.11.0` | `chart-testing` release tag (downloaded from `github.com/helm/chart-testing/releases`). Only used in `changed-charts` mode. |
| `ct_check_version_increment` | no | `true` | When `true`, pass `--check-version-increment=true` to `ct lint` (every changed chart must bump `Chart.yaml` `version`). |

<br/>

## Outputs

| Output | Values | Description |
|---|---|---|
| `lint_result` | `success` / `failure` / `skipped` | Result of the lint phase. `helm` mode: runs `helm lint`. `changed-charts` mode: runs `ct lint`. `skipped` only in `changed-charts` mode when no charts changed. Populated even when the action fails (use with `continue-on-error`). |
| `template_result` | `success` / `failure` / `skipped` | Result of the helm template phase. `skipped` when `run_template: 'false'` or (in `changed-charts` mode) when no charts changed. |
| `kubeconform_result` | `success` / `failure` / `skipped` | Result of the kubeconform phase. `skipped` when `run_kubeconform: 'false'` (default) or (in `changed-charts` mode) when no charts changed. |
| `changed_charts_count` | `'0'` / `'N'` | Number of charts detected as changed in `changed-charts` mode. Empty string in `helm` mode (the discover step does not run). |

<br/>

## Permissions

This action only reads the checkout and writes to `$GITHUB_STEP_SUMMARY`. A minimal `permissions: contents: read` at the job or workflow level is sufficient.

<br/>

## How It Works

1. **Validate inputs** — in `helm` mode: checks `chart_path` contains `Chart.yaml`, every `values_files` entry exists. In `changed-charts` mode: checks `charts_dir` is a directory under `working_directory`, `ct_version` matches a valid release tag, emits `::notice::` for ignored inputs (`chart_path`, `values_files`, `run_yamllint`, `yamllint_config`). Both modes: validates `kubeconform_version` when opt-in.
2. **`azure/setup-helm@v5`** — installs helm at the requested version.
3. **Install chart-testing** (`mode: changed-charts` only) — downloads the pinned `ct_version` tarball from `github.com/helm/chart-testing/releases` and places `ct` under `/usr/local/bin`.
4. **List changed charts** (`mode: changed-charts` only, id: `discover`) — runs `ct list-changed --target-branch <base_ref> --chart-dirs <charts_dir>` and exports `changed`, `count`, `charts` as step outputs.
5. **yamllint** (`helm` mode + `run_yamllint: true`) — pip-installs yamllint, then lints only `Chart.yaml` + `values*.yaml`.
6. **Helm lint** (id: `lint`) — `helm` mode: loops over `values_files`. `changed-charts` mode: when any chart changed, runs `ct lint --target-branch <base_ref> --chart-dirs <charts_dir> --check-version-increment=<ct_check_version_increment>` (ct internally calls helm lint per chart); when no charts changed, writes `lint_result=skipped` and exits 0.
7. **Helm template** (id: `template`) — `helm` mode: loops over `values_files` with `--debug`. `changed-charts` mode: loops over the discovered chart list with `--debug`. `skipped` when `run_template: false` or no charts changed.
8. **Kubeconform** (id: `kubeconform`, `run_kubeconform: true`) — downloads the pinned kubeconform binary (multi-arch), then pipes `helm template` output through `kubeconform -strict -ignore-missing-schemas -summary`. Same mode-aware looping as `template`. `skipped` when disabled or no charts changed.
9. **Summary** — a markdown table is appended to `$GITHUB_STEP_SUMMARY` on `if: always()` so failed runs still surface what was attempted.

See [CLAUDE.md](CLAUDE.md) for the full internal flow and the composite-output wiring rationale.

<br/>

## License

MIT. See [LICENSE](LICENSE).
