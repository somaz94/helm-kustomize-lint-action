# Changelog

All notable changes to this project will be documented in this file.

## Unreleased (2026-07-23)

### Continuous Integration

- remove DCO workflow ([acef979](https://github.com/somaz94/helm-kustomize-lint-action/commit/acef979eff5230de4bf3da80d3c4ccf46c53c34c))
- adopt semantic-pr, labels, lock-threads, PR size, and auto-assign reusables ([af646bc](https://github.com/somaz94/helm-kustomize-lint-action/commit/af646bc9be6c1df9bb4d9f0cdcf45f757c83cbd4))
- use reusable stale-issues workflow ([c1b029d](https://github.com/somaz94/helm-kustomize-lint-action/commit/c1b029de29c6917ce6796f0548f383a2d0f01978))
- use reusable issue-greeting workflow ([ef76383](https://github.com/somaz94/helm-kustomize-lint-action/commit/ef76383f331bb23487e6d096e5e261c04dfb2e5e))
- use reusable dependabot-auto-merge workflow ([9b454a8](https://github.com/somaz94/helm-kustomize-lint-action/commit/9b454a8079e7453ee71f977c8ee78346d79495fb))
- use reusable contributors workflow ([7e6446f](https://github.com/somaz94/helm-kustomize-lint-action/commit/7e6446f8df59ec42f821f65bd3ca4c7da69f9bf2))
- add ok-to-test workflow stub ([161e1ef](https://github.com/somaz94/helm-kustomize-lint-action/commit/161e1ef5fad5402aecb4292109f9efd7a100786e))
- add PR welcome workflow stub ([cdb9200](https://github.com/somaz94/helm-kustomize-lint-action/commit/cdb9200c922b15de5c79afefd0ec50c0389259be))
- add DCO check via shared reusable workflow ([5074fa0](https://github.com/somaz94/helm-kustomize-lint-action/commit/5074fa048c8afcc0b0d8d1ac825f767b2ebfd8d2))

### Chores

- **deps:** bump actions/setup-python from 6 to 7 ([099517b](https://github.com/somaz94/helm-kustomize-lint-action/commit/099517b375629b94631fc1a29e639ef19e0e365e))
- **deps:** bump actions/checkout from 6 to 7 (#1) ([#1](https://github.com/somaz94/helm-kustomize-lint-action/pull/1)) ([ad6dd8d](https://github.com/somaz94/helm-kustomize-lint-action/commit/ad6dd8d32990bb4dfb6a49e91e83b7aeaa88ea36))

### Contributors

- somaz

<br/>

## [v1.1.4](https://github.com/somaz94/helm-kustomize-lint-action/compare/v1.1.3...v1.1.4) (2026-06-04)

### Bug Fixes

- verify ct and kubeconform download checksums before install ([3d009fd](https://github.com/somaz94/helm-kustomize-lint-action/commit/3d009fd6e8cf70116db5a6a76f694232664666fe))

### Contributors

- somaz

<br/>

## [v1.1.3](https://github.com/somaz94/helm-kustomize-lint-action/compare/v1.1.2...v1.1.3) (2026-06-04)

### Bug Fixes

- detect ct list-changed failures and guard ct schema install ([6852e71](https://github.com/somaz94/helm-kustomize-lint-action/commit/6852e71a7dedf96ee9341f4f1055422a53745b6d))

### Contributors

- somaz

<br/>

## [v1.1.2](https://github.com/somaz94/helm-kustomize-lint-action/compare/v1.1.1...v1.1.2) (2026-06-04)

### Code Refactoring

- add loop-failure diagnostics and empty-array-safe expansion ([65e3857](https://github.com/somaz94/helm-kustomize-lint-action/commit/65e385772fed23e147d65500b2f1cce6cc53b590))

### Contributors

- somaz

<br/>

## [v1.1.1](https://github.com/somaz94/helm-kustomize-lint-action/compare/v1.1.0...v1.1.1) (2026-06-02)

### Bug Fixes

- re-enable pipefail in kubeconform loop to unmask helm errors ([d6def8a](https://github.com/somaz94/helm-kustomize-lint-action/commit/d6def8a5271e137425042fb0ce0718c61fabdc71))

### Continuous Integration

- add concurrency guards to recurring workflows ([c1926ac](https://github.com/somaz94/helm-kustomize-lint-action/commit/c1926acdd11276661af51e3d749f5bdf255bf866))

### Contributors

- somaz

<br/>

## [v1.1.0](https://github.com/somaz94/helm-kustomize-lint-action/compare/v1.0.0...v1.1.0) (2026-04-23)

### Features

- add changed-charts mode for Helm monorepos ([b46fc32](https://github.com/somaz94/helm-kustomize-lint-action/commit/b46fc32b2ecc32bd0b8289a18034ab6d14140370))

### Bug Fixes

- pip install yamale+yamllint for ct lint in changed-charts mode ([333beeb](https://github.com/somaz94/helm-kustomize-lint-action/commit/333beeb31549e53a47eeea149d5c33694b7240ac))
- install ct chart_schema.yaml + pin helm 3.16.4 for changed-charts ([b1ff453](https://github.com/somaz94/helm-kustomize-lint-action/commit/b1ff4533ebaefe94bf6c5e7f875f315fab3cc819))

### Continuous Integration

- add changed-charts test and smoke jobs ([5bf4509](https://github.com/somaz94/helm-kustomize-lint-action/commit/5bf4509728d22b8cda8a685083b26d25d3764bba))

### Chores

- add monorepo fixture for changed-charts mode ([07be850](https://github.com/somaz94/helm-kustomize-lint-action/commit/07be8507a77b4c810af3a8bd048aa93c1f0e6409))

### Contributors

- somaz

<br/>

## [v1.0.0](https://github.com/somaz94/helm-kustomize-lint-action/releases/tag/v1.0.0) (2026-04-22)

### Features

- implement helm-kustomize-lint-action ([4b6b147](https://github.com/somaz94/helm-kustomize-lint-action/commit/4b6b1479247cdb592eb85d2aea1080c8f85b9457))

### Continuous Integration

- add release, mirror, and changelog workflows ([6dec88c](https://github.com/somaz94/helm-kustomize-lint-action/commit/6dec88c0b594a19519103f4587e04eb4f2d4a539))

### Chores

- add baseline repo files and license ([7848307](https://github.com/somaz94/helm-kustomize-lint-action/commit/7848307efb1897d7a35c90c6bcb16d78a58c75a7))

### Contributors

- somaz

<br/>

