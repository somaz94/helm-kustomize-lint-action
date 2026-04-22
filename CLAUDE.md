# CLAUDE.md

<br/>

## Project Structure

- Composite GitHub Action (no Docker image — `runs.using: composite`)
- Replaces the shared Helm CI prelude that `helm-charts` / `certmanager-letsencrypt` / `helm-chart-template` copy-paste: `azure/setup-helm` + `yamllint` + `helm lint` (per values file) + `helm template --debug` + optional `kubeconform` validation
- Defaults target a single-chart layout (`chart_path=.`) with the chart's own `values.yaml` auto-loaded by helm — zero config for a repo whose chart lives at the repo root
- Multi-env charts (AWS/GCP/Cloudflare-style) use the `values_files` multi-line input so each values file is linted and rendered independently, mirroring `certmanager-letsencrypt`'s existing `helm lint ./helm -f values-<env>.yaml` pattern
- `kubeconform` is opt-in because it needs CRD schema locations for anything beyond stock Kubernetes kinds (Gateway API, Prometheus Operator, etc.)
- The "kustomize" in the action name is reserved for a future v1.1.0+ expansion — v1.0.0 is helm-only

<br/>

## Key Files

- `action.yml` — composite action (**11 inputs**, **3 outputs**). Flow: validate inputs → `azure/setup-helm@v5` → optional yamllint on `Chart.yaml` + `values*.yaml` (templates are Go-template, skipped) → helm lint (per values file, single step id=`lint`) → helm template (per values file, single step id=`template`) → optional kubeconform install + validate (single step id=`kubeconform`) → markdown summary on `if: always()`.
- `tests/fixtures/sample_chart/` — minimal nginx Deployment + Service chart (`Chart.yaml`, `values.yaml`, `values-prod.yaml`, `templates/{_helpers.tpl,deployment.yaml,service.yaml,NOTES.txt}`), zero external deps, zero CRDs — kubeconform validates against stock Kubernetes schemas.
- `tests/fixtures/broken_chart/` — intentionally-broken fixture (`templates/deployment.yaml` references `required "..." .Values.image.repository` with `image.repository` unset in `values.yaml`) so `helm lint` fails with a known message. The failure-path CI job asserts `outcome=failure` and `lint_result=failure`.
- `cliff.toml` — git-cliff config for release notes.
- `Makefile` — `lint` (dockerized yamllint), `test` / `test-fixture` (helm lint the fixture locally, needs `helm` in PATH), `template-fixture` (render), `kubeconform-fixture` (needs `kubeconform` in PATH), `clean`.

<br/>

## Build & Test

There is no local "build" — composite actions execute on the GitHub Actions runner.

```bash
make lint                 # yamllint action.yml + workflows + fixtures (dockerized)
make test-fixture         # helm lint tests/fixtures/sample_chart --strict (needs helm)
make template-fixture     # helm template --debug for defaults + values-prod.yaml
make kubeconform-fixture  # helm template | kubeconform -strict (needs kubeconform)
make clean                # remove any *.tgz produced by local `helm package`
```

`make lint` only needs Docker. `make test-fixture` / `make template-fixture` need `helm`. `make kubeconform-fixture` additionally needs `kubeconform`. The `ci.yml` workflow covers the full path (including kubeconform install) on the GitHub runner.

<br/>

## Workflows

- `ci.yml` — `lint` (yamllint + actionlint) + `test-action` (defaults against `sample_chart`, asserts `lint_result=success`, `template_result=success`, `kubeconform_result=skipped`) + `test-action-multi-values` (2 values files + `run_template=false`, asserts `template_result=skipped` but `lint_result=success`) + `test-action-kubeconform` (pinned `helm_version=v3.16.4` + `run_kubeconform=true`, asserts `kubeconform_result=success`) + `test-action-failure` (`broken_chart` + `run_yamllint=false` + `continue-on-error`, asserts `outcome=failure` and `lint_result=failure`) + `ci-result` aggregator.
- `release.yml` — git-cliff release notes + `softprops/action-gh-release@v3` + `somaz94/major-tag-action@v1` for the `v1` sliding tag.
- `use-action.yml` — post-release smoke test. Runs `somaz94/helm-kustomize-lint-action@v1` against the fixture in two flavours: defaults (kubeconform skipped) and `run_kubeconform=true` with 2 values files.
- `gitlab-mirror.yml`, `changelog-generator.yml`, `contributors.yml`, `dependabot-auto-merge.yml`, `issue-greeting.yml`, `stale-issues.yml` — standard repo automation shared with sibling `somaz94/*-action` repos.

<br/>

## Release

Push a `vX.Y.Z` tag → `release.yml` runs → GitHub Release published → `v1` major tag updated → `use-action.yml` smoke-tests the published version against the fixture (both default and kubeconform paths).

<br/>

## Action Inputs

Required: none (fully default-driven for a single-chart, Chart.yaml-at-root layout).

Tuning: `chart_path` (default `.`), `values_files` (default `''`, multiline), `helm_version` (default `latest`), `working_directory` (default `.`), `lint_strict` (default `true`), `run_yamllint` (default `true`), `yamllint_config` (default `''`, uses `-d relaxed`), `run_template` (default `true`), `run_kubeconform` (default `false`), `kubeconform_version` (default `v0.6.7`), `kubeconform_schema_locations` (default `default`, multiline).

See [README.md](README.md) for the full table.

<br/>

## Internal Flow

1. **Validate inputs** — `working_directory` exists, `chart_path` is a directory under it, `Chart.yaml` present at `working_directory/chart_path/Chart.yaml`, each entry in `values_files` resolves to an existing file under `working_directory`, `yamllint_config` (when non-empty and `run_yamllint=true`) resolves, `kubeconform_version` matches `^v[0-9]+\.[0-9]+\.[0-9]+$` when `run_kubeconform=true`.
2. **`azure/setup-helm@v5`** — installs helm at `inputs.helm_version` (`latest` or a pinned `v3.16.x` tag).
3. **yamllint** (gated on `run_yamllint == 'true'`) — `python3 -m pip install --quiet yamllint`, then `yamllint` over `chart_path/Chart.yaml` + `chart_path/values*.yaml` (+ `*.yml`) only. Templates are **not** linted because Helm Go-template syntax (e.g., `{{ .Values.foo }}`) is not valid YAML and produces useless noise. When `yamllint_config` is empty, uses `-d relaxed`; when non-empty, uses `-c <config>`. Yamllint failure fails the whole action early (no output is reserved for it — `lint_result` refers specifically to `helm lint`).
4. **Helm lint** (`id: lint`, single step, always runs) — per-values-file loop. When `values_files` is empty, a single `helm lint "$chart_path"` call. When non-empty, one `helm lint "$chart_path" -f "$vfile"` per line. `--strict` added when `lint_strict=true`. Each loop iteration's exit code is captured; the aggregate return code drives `lint_result` (`success` if all zero, `failure` otherwise). The output is written to `$GITHUB_OUTPUT` **before** the final `exit $RC` so the composite-output single-step-id rule holds even on failure.
5. **Helm template** (`id: template`, single step, always runs) — identical loop shape; branches internally on `run_template`. When disabled, writes `template_result=skipped` and `exit 0` — the step still runs so its output is wired. When enabled, `helm template ci-render "$chart_path" [-f <vfile>] --debug > /dev/null` per file. Aggregate result drives `template_result`.
6. **Kubeconform** (`id: kubeconform`, single step, always runs) — branches internally on `run_kubeconform`. When disabled, writes `kubeconform_result=skipped` and `exit 0`. When enabled, detects host arch (`x86_64` → `amd64`, `aarch64`/`arm64` → `arm64`), downloads the pinned kubeconform tarball from GitHub releases, installs to `/usr/local/bin/kubeconform` with `sudo install`, then pipes each `helm template ci-render "$chart_path" [-f <vfile>]` into `kubeconform -strict -ignore-missing-schemas -summary <schema-args>`. `kubeconform_schema_locations` multi-line input is converted to one `-schema-location <value>` pair per non-empty line; defaults to `-schema-location default` (the bundled Kubernetes schemas).
7. **Summary** (`if: always()`) — markdown table (working directory, chart path, values files, yamllint flag, helm lint strict flag + result, template result, kubeconform result) appended to `$GITHUB_STEP_SUMMARY`. Runs even on failure so a failed run still surfaces what was attempted.

<br/>

## Composite Output Wiring

Three outputs (`lint_result`, `template_result`, `kubeconform_result`), all following the single-step-id rule that Phase B (`go-kubebuilder-test-action`) established — a composite top-level `outputs.<name>.value: ${{ steps.<id>.outputs.<name> }}` only tracks one `steps.<id>`:

- `lint_result` is set by the `lint` step, which always runs. The step writes `lint_result=success` or `lint_result=failure` **before** `exit $RC`, so even when the step fails the output is populated — callers using `continue-on-error: true` can read `lint_result` to diagnose.
- `template_result` is set by the `template` step, which always runs. Branches internally on `run_template`: writes `skipped` and `exit 0` when disabled, `success` / `failure` when enabled. Callers never see an empty `template_result` (unlike the `test_exit_code` contract in `go-docker-action-ci-action`, where the step itself is gated off).
- `kubeconform_result` is set by the `kubeconform` step, which always runs. Same three-value shape (`success` / `failure` / `skipped`). The install sub-stage (`set -e` around curl+install) is intentionally inside the same step so a failed install also routes through the single output (step exits non-zero with `kubeconform_result` unset; callers should treat an empty `kubeconform_result` the same as `failure`).

All three steps share the same "write output before exit" pattern: `set +e` around the actual work, capture `$?`, write the branch's result to `$GITHUB_OUTPUT`, then `exit $RC`. This keeps the single-step-id rule intact on both success and failure paths.

The yamllint step and the summary step deliberately do not feed any action output — they're side-effect-only (pre-check and post-run markdown). If a future version needs to expose `yamllint_result`, add a 4th output wired to the yamllint step id, not to the existing `lint` step.
