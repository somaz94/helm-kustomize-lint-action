# CLAUDE.md

<br/>

## Project Structure

- Composite GitHub Action (no Docker image — `runs.using: composite`)
- Replaces the shared Helm CI prelude that `helm-charts` / `certmanager-letsencrypt` / `helm-chart-template` / `helm-base-app-template` copy-paste: `azure/setup-helm` + `yamllint` + `helm lint` (per values file) + `helm template --debug` + optional `kubeconform` validation
- Two modes via `mode` input:
  - `helm` (default, v1.0.x compatible): single-chart layout — `chart_path` + `values_files` loop
  - `changed-charts` (v1.1.0+): Helm monorepo — `ct list-changed` + `ct lint` (with `--check-version-increment`) + `helm template` / `kubeconform` loop over changed charts. `ct` binary downloaded from `github.com/helm/chart-testing/releases` per `ct_version`. Caller must `checkout` with `fetch-depth: 0`.
- Defaults target a single-chart layout (`chart_path=.`, `mode=helm`) with the chart's own `values.yaml` auto-loaded by helm — zero config for a repo whose chart lives at the repo root
- Multi-env charts (AWS/GCP/Cloudflare-style) use the `values_files` multi-line input so each values file is linted and rendered independently, mirroring `certmanager-letsencrypt`'s existing `helm lint ./helm -f values-<env>.yaml` pattern
- `kubeconform` is opt-in because it needs CRD schema locations for anything beyond stock Kubernetes kinds (Gateway API, Prometheus Operator, etc.)
- The "kustomize" in the action name is still reserved — targeted at v1.2.0+ (kustomize build + validation mode). v1.1.0 only adds Helm monorepo support.

<br/>

## Key Files

- `action.yml` — composite action (**16 inputs**, **4 outputs** as of v1.1.0). Flow: validate inputs → `azure/setup-helm@v5` → (changed-charts only) install `ct` + `discover` step → optional yamllint (helm mode only) → helm lint / ct lint (step id=`lint`) → helm template (step id=`template`) → optional kubeconform (step id=`kubeconform`) → markdown summary on `if: always()`.
- `tests/fixtures/sample_chart/` — minimal nginx Deployment + Service chart (`Chart.yaml`, `values.yaml`, `values-prod.yaml`, `templates/{_helpers.tpl,deployment.yaml,service.yaml,NOTES.txt}`), zero external deps, zero CRDs — kubeconform validates against stock Kubernetes schemas. Used by `helm` mode CI jobs.
- `tests/fixtures/broken_chart/` — intentionally-broken fixture (`templates/deployment.yaml` references `required "..." .Values.image.repository` with `image.repository` unset in `values.yaml`) so `helm lint` fails with a known message. The failure-path CI job asserts `outcome=failure` and `lint_result=failure`.
- `tests/fixtures/monorepo/` — two-chart Helm monorepo fixture (`charts/chart-a/` Deployment + `charts/chart-b/` ConfigMap, both with `maintainers:` so `ct lint` passes). Used by `changed-charts` mode CI jobs that simulate a chart-a-only change via a scratch git branch in CI.
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

- `ci.yml` — `lint` (yamllint + actionlint) + `test-action` (defaults against `sample_chart`, asserts `lint_result=success`, `template_result=success`, `kubeconform_result=skipped`) + `test-action-multi-values` (2 values files + `run_template=false`, asserts `template_result=skipped` but `lint_result=success`) + `test-action-kubeconform` (pinned `helm_version=v3.16.4` + `run_kubeconform=true`, asserts `kubeconform_result=success`) + `test-action-failure` (`broken_chart` + `run_yamllint=false` + `continue-on-error`, asserts `outcome=failure` and `lint_result=failure`) + `test-action-changed-charts` (monorepo fixture + scratch git branch bumps chart-a version → asserts `lint_result=success`, `template_result=success`, `changed_charts_count=1`) + `test-action-changed-charts-empty` (monorepo fixture + no change vs main → asserts all 3 results `skipped`, `changed_charts_count=0`) + `ci-result` aggregator.
- `release.yml` — git-cliff release notes + `softprops/action-gh-release@v3` + `somaz94/major-tag-action@v1` for the `v1` sliding tag.
- `use-action.yml` — post-release smoke test. Runs `somaz94/helm-kustomize-lint-action@v1` against the fixture in three flavours: defaults (kubeconform skipped), `run_kubeconform=true` with 2 values files, and `mode: changed-charts` against the monorepo fixture with a scratch git branch.
- `gitlab-mirror.yml`, `changelog-generator.yml`, `contributors.yml`, `dependabot-auto-merge.yml`, `issue-greeting.yml`, `stale-issues.yml` — standard repo automation shared with sibling `somaz94/*-action` repos.

<br/>

## Release

Push a `vX.Y.Z` tag → `release.yml` runs → GitHub Release published → `v1` major tag updated → `use-action.yml` smoke-tests the published version against the fixture (both default and kubeconform paths).

<br/>

## Action Inputs

Required: none (fully default-driven for a single-chart, Chart.yaml-at-root layout in `helm` mode).

**helm mode tuning**: `chart_path` (default `.`), `values_files` (default `''`, multiline), `helm_version` (default `latest`), `working_directory` (default `.`), `lint_strict` (default `true`), `run_yamllint` (default `true`), `yamllint_config` (default `''`, uses `-d relaxed`), `run_template` (default `true`), `run_kubeconform` (default `false`), `kubeconform_version` (default `v0.6.7`), `kubeconform_schema_locations` (default `default`, multiline).

**changed-charts mode (v1.1.0+)**: `mode: changed-charts`, `base_ref` (default `main`), `charts_dir` (default `charts`), `ct_version` (default `v3.11.0`), `ct_check_version_increment` (default `true`). `run_template` / `run_kubeconform` / `kubeconform_*` apply as in helm mode. `chart_path` / `values_files` / `run_yamllint` / `yamllint_config` / `lint_strict` are **ignored** (notice-logged) — ct lint has its own schema/version/yamllint validation and does not accept a `--strict` flag or per-values linting.

See [README.md](README.md) for the full table.

<br/>

## Internal Flow

1. **Validate inputs** — `mode` is `helm` or `changed-charts`; `working_directory` exists. In `helm` mode: `chart_path` is a directory under `working_directory`, `Chart.yaml` present at `working_directory/chart_path/Chart.yaml`, each entry in `values_files` resolves to an existing file under `working_directory`, `yamllint_config` (when non-empty and `run_yamllint=true`) resolves. In `changed-charts` mode: `base_ref` + `charts_dir` non-empty, `charts_dir` is a directory under `working_directory`, `ct_version` matches `^v[0-9]+\.[0-9]+\.[0-9]+$`; emits `::notice::` for inputs that don't apply (`chart_path`, `values_files`, `run_yamllint`). Both modes: `kubeconform_version` matches the same regex when `run_kubeconform=true`.
2. **`azure/setup-helm@v5`** — installs helm at `inputs.helm_version` (`latest` or a pinned `v3.16.x` tag). Always runs.
3. **Install chart-testing** (gated on `mode == 'changed-charts'`) — detects host arch, downloads `chart-testing_<X.Y.Z>_linux_<arch>.tar.gz` from `github.com/helm/chart-testing/releases/download/<ct_version>/...`, `sudo install -m 0755 ct /usr/local/bin/ct`. Schemas are embedded in ct 3.x so no external `etc/` copy needed.
4. **List changed charts** (`id: discover`, gated on `mode == 'changed-charts'`) — `ct list-changed --target-branch "$BASE_REF" --chart-dirs "$CHARTS_DIR"` (wrapped in `|| true` so ct's own non-zero exits don't fail the step before we inspect output). Writes `changed=true|false`, `count=<N|0>`, `charts=<multiline>` to `$GITHUB_OUTPUT`. Downstream `lint` / `template` / `kubeconform` steps read `steps.discover.outputs.{changed,charts}` via the `env:` block. Also drives the `changed_charts_count` action output.
5. **yamllint** (gated on `run_yamllint == 'true' && mode != 'changed-charts'`) — `python3 -m pip install --quiet yamllint`, then `yamllint` over `chart_path/Chart.yaml` + `chart_path/values*.yaml` (+ `*.yml`) only. Templates are **not** linted (Helm Go-template syntax is not valid YAML and would produce noise). When `yamllint_config` is empty, uses `-d relaxed`; when non-empty, uses `-c <config>`. Yamllint failure fails the whole action early (no output is reserved for it — `lint_result` refers specifically to helm lint / ct lint). Skipped in `changed-charts` mode because `ct lint` runs its own yamale/yamllint checks.
6. **Helm lint** (`id: lint`, single step, always runs, branches on `mode`) — `helm` mode: per-values-file loop. When `values_files` is empty, a single `helm lint "$chart_path"` call; when non-empty, one `helm lint "$chart_path" -f "$vfile"` per line. `--strict` added when `lint_strict=true`. `changed-charts` mode: if no charts changed → `lint_result=skipped`, exit 0. Else `ct lint --target-branch "$BASE_REF" --chart-dirs "$CHARTS_DIR" --check-version-increment="$CT_CHECK_VERSION_INCREMENT"` (ct internally runs helm lint per chart + validates `Chart.yaml` schema + maintainers + version increment). Aggregate/single return code drives `lint_result` (`success|failure|skipped`). Output is written to `$GITHUB_OUTPUT` **before** the final `exit $RC` so the composite-output single-step-id rule holds even on failure.
7. **Helm template** (`id: template`, single step, always runs, branches on `mode`) — branches internally on `run_template` first (writes `skipped` + exit 0 when disabled). `helm` mode: identical loop shape to helm lint, but `helm template ci-render "$chart_path" [-f <vfile>] --debug > /dev/null`. `changed-charts` mode: if no charts changed → `template_result=skipped`, exit 0. Else loops over `$CHANGED_CHARTS` (multi-line env from `steps.discover.outputs.charts`), running `helm template ci-render "$chart" --debug` per changed chart path. Aggregate result drives `template_result`.
8. **Kubeconform** (`id: kubeconform`, single step, always runs, branches on `mode`) — branches internally on `run_kubeconform` first (writes `skipped` + exit 0 when disabled) **and** on "no changed charts" when in `changed-charts` mode (same early skip). Otherwise: detects host arch (`x86_64` → `amd64`, `aarch64`/`arm64` → `arm64`), downloads the pinned kubeconform tarball from GitHub releases, installs to `/usr/local/bin/kubeconform` with `sudo install`, then pipes each rendering into `kubeconform -strict -ignore-missing-schemas -summary <schema-args>`. Loop shape mirrors `template` — per values file in `helm` mode, per changed chart in `changed-charts` mode. `kubeconform_schema_locations` multi-line input is converted to one `-schema-location <value>` pair per non-empty line; defaults to `-schema-location default`.
9. **Summary** (`if: always()`) — markdown table (mode, working directory, either `chart_path` + `values_files` + yamllint/strict flags OR `charts_dir` + `base_ref` + changed count + changed list + version-increment flag, plus lint/template/kubeconform results) appended to `$GITHUB_STEP_SUMMARY`. Runs even on failure so a failed run still surfaces what was attempted.

<br/>

## Composite Output Wiring

Four outputs (`lint_result`, `template_result`, `kubeconform_result`, `changed_charts_count`), all following the single-step-id rule that Phase B (`go-kubebuilder-test-action`) established — a composite top-level `outputs.<name>.value: ${{ steps.<id>.outputs.<name> }}` only tracks one `steps.<id>`:

- `lint_result` is set by the `lint` step, which always runs. The step writes `lint_result=success|failure|skipped` **before** `exit $RC`, so even when the step fails the output is populated — callers using `continue-on-error: true` can read `lint_result` to diagnose. `skipped` is new in v1.1.0 and only appears when `mode=changed-charts` with no detected changes.
- `template_result` is set by the `template` step, which always runs. Branches internally on `run_template` first and on "no changed charts" second: writes `skipped` and `exit 0` when disabled or no work to do, `success` / `failure` when real rendering happens.
- `kubeconform_result` is set by the `kubeconform` step, which always runs. Same three-value shape (`success` / `failure` / `skipped`). The install sub-stage (`set -e` around curl+install) is intentionally inside the same step so a failed install also routes through the single output (step exits non-zero with `kubeconform_result` unset; callers should treat an empty `kubeconform_result` the same as `failure`).
- `changed_charts_count` is set by the `discover` step, which **does not always run** (gated on `mode == 'changed-charts'`). When the step does not run, the output resolves to empty string (`''`). Callers treat empty as "mode=helm — not applicable" and a numeric string as "mode=changed-charts — N charts changed". This is the only v1.1.0 output that uses a step-id (`discover`) that is not shared with lint/template/kubeconform.

All three result-bearing steps (`lint`, `template`, `kubeconform`) share the same "write output before exit" pattern: `set +e` around the actual work, capture `$?`, write the branch's result to `$GITHUB_OUTPUT`, then `exit $RC`. This keeps the single-step-id rule intact on both success and failure paths.

The yamllint step and the summary step deliberately do not feed any action output — they're side-effect-only (pre-check and post-run markdown). If a future version needs to expose `yamllint_result`, add a 5th output wired to the yamllint step id, not to the existing `lint` step.

### Passing data between steps in changed-charts mode

The `discover` step exports `charts` (multi-line) via a heredoc-style `$GITHUB_OUTPUT` block:

```
{
  echo "charts<<EOF"
  printf '%s\n' "$CHANGED"
  echo "EOF"
} >> "$GITHUB_OUTPUT"
```

Downstream steps read it via `env: CHANGED_CHARTS: ${{ steps.discover.outputs.charts }}` and iterate with `while IFS= read -r chart; ...; done <<< "$CHANGED_CHARTS"`. The same `env:` pattern is used for `steps.discover.outputs.changed` (truthy gate) so each step decides internally whether to do work, write `skipped`, or branch to the helm-mode path.
